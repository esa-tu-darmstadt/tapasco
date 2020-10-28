/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco.slurm

import java.nio.file._
import java.nio.file.attribute.PosixFilePermission._

import tapasco.Logging._
import tapasco.filemgmt._
import tapasco.task.ResourceConsumer
import tapasco.util.{Publisher, Template}

import scala.collection.JavaConverters._
import scala.sys.process._

/**
  * Primitive interface to SLURM scheduler:
  * Can be used to generate job scripts and schedule them on SLURM via `sbatch`.
  * Provides methods to write the script, schedule and wait for it.
  **/
final object Slurm extends Publisher {
  private implicit val logger = tapasco.Logging.logger(getClass)
  private val SLURM_RETRIES = 10

  /** Model of a SLURM job. */
  final case class Job(
                        /** Name of the job. */
                        name: String,

                        /** File name of the tapasco logfile. */
                        log: Path,

                        /** File name of the stdout slurm logfile. */
                        slurmLog: Path,

                        /** File name of the stderr slurm logfile. */
                        errorLog: Path,

                        /** Consumer to schedule. */
                        consumer: ResourceConsumer,

                        /** Time limit (in hours). */
                        maxHours: Int,

                        /** Sequence of commands to execute (bash). */
                        commands: Seq[String],

                        /** Optional comment. */
                        comment: Option[String] = None,

                        /** The job to execute */
                        job: tapasco.jobs.Job,

                        /** Filename of the tapasco configuration file */
                        cfg_file: Path
                      )

  /** Exception class for negative SLURM responses. */
  final case class SlurmException(script: String, sbatchOutput: String)
    extends Exception("SLURM exception during execution of %s, output text: '%s'".format(script, sbatchOutput))

  sealed trait Event

  final object Events {

    /** SLURM activation changed. */
    final case class SlurmModeEnabled(enabled: Boolean) extends Event

  }

  /** Template file for job script. */
  final val slurmTemplate = FileAssetManager.TAPASCO_HOME.resolve("common").resolve("slurm.job.template")
  /** Default output directory for SLURM-related outputs. */
  final val slurmOutput = FileAssetManager.TAPASCO_HOME.resolve("slurm")
  /** Regular expression: Positive ACK from `sbatch`. */
  final val slurmSubmissionAck =
    """[Ss]ubmitted batch job (\d+)""".r
  /** Polling interval for `squeue`. */
  final val slurmDelay = 15000 // 15 secs
  /** Set of POSIX permissions for SLURM job scripts. */
  final val slurmScriptPermissions = Set(OWNER_READ, OWNER_WRITE, OWNER_EXECUTE, GROUP_READ, OTHERS_READ).asJava
  /** Wait interval between retries. */
  final val slurmRetryDelay = 10000 // 10 secs

  /** Returns true if SLURM is available on host running iTPC. */
  lazy val available: Boolean = "which sbatch".! == 0

  /** Returns true, if SLURM is available and enabled. */
  def enabled: Boolean = Slurm.synchronized {
    _enabled
  }

  /** Enables or disables SLURM, returns new value for enabled. */
  def set_cfg(cfg: SlurmConfig): Boolean = cfg match {
    case Disabled() => false
    case EnabledLocal() => if (available) {
      Slurm.synchronized {
        _enabled = true
      }
      publish(Events.SlurmModeEnabled(true))
      true
    } else {
      logger.warn("SLURM local mode was selected, but could be not activated (sbatch not found)")
      false
    }
    case EnabledRemote(template_name) => {
      val template_path = SLURM_TEMPLATE_DIR.resolve(template_name + ".json")
      if (template_path.toFile.exists()) {
        Slurm.synchronized {
          _enabled = true
          slurm_remote_cfg = SlurmRemoteConfig.from(template_path).toOption
        }
        publish(Events.SlurmModeEnabled(true))
        true
      } else {
        logger.warn("SLURM mode was selected, but the specified template was not found")
        false
      }
    }
  }

  /** Helper function: Sets correct file permissions on job scripts. */
  def setScriptPermissions(script: Path): Unit = Files.setPosixFilePermissions(script, slurmScriptPermissions)

  /**
    * Write a SLURM job script to given file.
    *
    * @param job  Job to execute.
    * @param file File to write script to.
    * @return True, iff successful.
    **/
  def writeJobScript(job: Job, file: Path): Boolean = (catchDefault[Boolean](false, Seq(classOf[java.io.IOException]),
    prefix = "could not write %s: ".format(file.toString)) _) {
    // fill in template needles
    val jobScript = new Template
    jobScript("JOB_NAME") = job.name
    jobScript("SLURM_LOG") = job.slurmLog
    jobScript("ERROR_LOG") = job.errorLog
    jobScript("MEM_PER_CPU") = (job.consumer.memory / 1024).toString
    jobScript("CPUS") = (job.consumer.cpus).toString
    jobScript("TIMELIMIT") = "%02d:00:00".format(job.maxHours)
    jobScript("TAPASCO_HOME") = FileAssetManager.TAPASCO_HOME.toString
    jobScript("COMMANDS") = job.commands mkString "\n"
    jobScript("COMMENT") = job.comment getOrElse ""
    // create parent directory
    Files.createDirectories(file.getParent())
    // write file
    val fw = new java.io.FileWriter(file.toString)
    fw.append(jobScript.interpolateFile(Slurm.slurmTemplate.toString))
    fw.flush()
    fw.close()
    // set executable permissions
    setScriptPermissions(file)
    true
  }

  /**
    * Schedules a job on SLURM.
    *
    * @param script Job script file to schedule via `sbatch`.
    * @return Either a positive integer (SLURM id), or an Exception.
    **/
  def apply(script: Path, retries: Int = SLURM_RETRIES): Option[Int] =
    catchAllDefault[Option[Int]](None, "Slurm scheduling failed: ") {
      val cmd = "sbatch %s".format(script.toAbsolutePath().normalize().toString)
      logger.debug("running slurm batch job: '%s'".format(cmd))
      val res = exec_cmd(cmd)
      val id = slurmSubmissionAck.findFirstMatchIn(res) map (_ group (1) toInt)
      if (id.isEmpty) {
        if (retries > 0) {
          // wait for 10 secs + random up to 5 secs to avoid congestion
          Thread.sleep(slurmRetryDelay + scala.util.Random.nextInt() % (slurmRetryDelay / 2))
          apply(script, retries - 1)
        } else {
          throw new SlurmException(script.toString, res)
        }
      } else {
        logger.debug("received SLURM id: {}", id)
        id
      }
    }

  /** Check via `squeue` if the SLURM job is still running. */
  def isRunning(id: Int): Boolean = catchAllDefault[Boolean](true, "Slurm `squeue` failed: ") {
   val squeue = exec_cmd("squeue -h")
    logger.trace("squeue output: {}", squeue)
    !"%d".format(id).r.findFirstIn(squeue).isEmpty
  }

  /** Wait until the given SLURM job disappears from `squeue` output. */
  def waitFor(id: Int): Unit = {
    while (isRunning(id)) {
      logger.trace("SLURM job #%d is still running, sleeping for %d secs ...".format(id, slurmDelay / 1000))
      Thread.sleep(slurmDelay)
    }
  }

  /** Returns a list of all SLURM job ids which are registered under the
    * the current user's account. */
  def jobs(): Seq[Int] = if (!enabled) {
    Seq()
  } else {
    catchAllDefault(Seq[Int](), "could not get squeue output: ") {
      val lines = exec_cmd("squeue -u %s".format(sys.env("USER")))
      val ids = ("""\n\s*(\d+)""".r.unanchored.findAllMatchIn(lines) map (m => m.group(1).toInt)).toSeq
      logger.debug("running SLURM jobs: {}", ids mkString " ")
      ids
    }
  }

  /** Cancels the SLURM job with the given ID. */
  def cancel(id: Int): Unit = catchAllDefault((), "canceling SLURM job %d failed: ".format(id)) {
    exec_cmd("scancel %d".format(id))
  }

  /** Cancels all currently running SLURM jobs. */
  def cancelAllJobs(): Unit = catchAllDefault((), "canceling SLURM jobs failed: ") {
    val ids = jobs()
    if (ids.length > 0) {
      val cmd = "scancel %s" format (ids mkString " ")
      logger.info("canceling SLURM jobs: {}", ids mkString ", ")
      logger.debug("command: '{}'", cmd)
      exec_cmd(cmd, get_ret_code = true).toInt
    }
  }

  /** Execute a SLURM command, either locally or on a remote host */
  def exec_cmd(c: String, get_ret_code: Boolean = false, hostname: Option[String] = None): String = {
    val cmd = if (slurm_remote_cfg.isEmpty) c else {
      val host = hostname.getOrElse(slurm_remote_cfg.get.host)
      "ssh %s %s".format(host, c)
    }

    logger.info("Executing command: %s".format(cmd))
    if (get_ret_code) cmd.!.toString else cmd.!!
  }

  /** Use SLURM? */
  private var _enabled = false

  /** Host for executing SLURM */
  private var slurm_remote_cfg: Option[SlurmRemoteConfig] = None

  sealed trait SlurmConfig
  final case class EnabledLocal() extends SlurmConfig
  final case class EnabledRemote(template_name: String) extends SlurmConfig
  final case class Disabled() extends SlurmConfig
}
