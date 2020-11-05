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

import tapasco.Common
import tapasco.Logging._
import tapasco.activity.composers.Composer
import tapasco.base.{Configuration, SlurmRemoteConfig, Target}
import tapasco.filemgmt._
import tapasco.task.ResourceConsumer
import tapasco.util.{Publisher, Template}

import scala.collection.JavaConverters._
import scala.sys.process._
import tapasco.base.json._
import tapasco.jobs.{ComposeJob, HighLevelSynthesisJob}

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
  final val SLURM_TEMPLATE_DIR =  Common.commonDir.resolve("SLURM");
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
  /** Stores a closure for every slurm job id, which is called once that job finishes. */
  var postambles: Map[Int, Int => Unit] = Map()

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
    * @param upd_wd Function that converts local workdir file paths to valid paths on a remote SLURM node.
    * @return True, iff successful.
    **/
  def writeJobScript(job: Job, file: Path, upd_wd: Path => Path): Boolean =
    (catchDefault[Boolean](false, Seq(classOf[java.io.IOException]), prefix = "could not write %s: ".format(file.toString)) _) {
    // fill in template needles
    val jobScript = new Template
    jobScript("JOB_NAME") = job.name
    jobScript("SLURM_LOG") = upd_wd(job.slurmLog).toString
    jobScript("ERROR_LOG") = upd_wd(job.errorLog).toString
    jobScript("MEM_PER_CPU") = (job.consumer.memory / 1024).toString
    jobScript("CPUS") = (job.consumer.cpus).toString
    jobScript("TIMELIMIT") = "%02d:00:00".format(job.maxHours)
    jobScript("TAPASCO_HOME") = upd_wd(FileAssetManager.TAPASCO_WORK_DIR).toString
    jobScript("COMMANDS") = "tapasco --configFile %s".format(upd_wd(job.cfg_file).toString)
    jobScript("COMMENT") = job.comment getOrElse ""
    // create parent directory
    Files.createDirectories(file.getParent())
    // write file
    val fw = new java.io.FileWriter(file.toString)
    val template_name = slurm_remote_cfg match {
      case Some(c) => c.jobFile
      case None => "default.job.template"
    }
    fw.append(jobScript.interpolateFile(SLURM_TEMPLATE_DIR.resolve(template_name).toString))
    fw.flush()
    fw.close()
    // set executable permissions
    setScriptPermissions(file)
    true
  }

  /**
    * Preamble is run before the SLURM job is started.
    * Copy required files from host to SLURM workstation.
    * @param slurm_job  Job to execute.
    * @param files List of files that need to be copied to SLURM node
    * @param update_paths Function that converts local workdir file paths to valid paths on a remote SLURM node.
    **/
  def slurm_preamble(slurm_job: Job, files: Seq[Path], update_paths: Path => Path)(implicit cfg: Configuration): Unit = {
    val local_files: Seq[Path] = slurm_job.job match {
      case ComposeJob(c, _, _, a, p, _, _, _, _, _) => {
        val tgt = Target.fromString(a.get.head, p.get.head).get
        val cores = c.composition.map(ce => FileAssetManager.entities.core(ce.kernel, tgt))

        // TODO: In case there are no local ipcores, they are synth'ed prior to compose job, This is done LOCALLY
        files ++ cores.map(_.get.zipPath) ++ cores.map(_.get.descPath)
      }
      case HighLevelSynthesisJob(_, _, _, k, _) => {
        val kernels = FileAssetManager.entities.kernels.filter( kernel => k.get.contains(kernel.name) ).toSeq
        files ++ kernels.map(_.descPath.getParent)
      }
      case _ => files
    }
    val remote_files = local_files map update_paths
    file_transfer(local_files.zip(remote_files).toMap, tx = true)

    // run preamble script, if specified
    if (slurm_remote_cfg.get.PreambleScript.isDefined)
      "sh %s".format(slurm_remote_cfg.get.PreambleScript.get).!
  }

  /**
    * Postamble is run after the SLURM job is finished.
    * Copy generated artefacts back from the SLURM node.
    * @param slurm_job  Job to execute.
    * @param files List of (local) filenames that need to be copied from SLURM node to local machine
    * @param update_paths Function that converts local workdir file paths to valid paths on a remote SLURM node.
    **/
  def slurm_postamble(slurm_job: Job, files: Seq[Path], update_paths: Path => Path): Unit = {
    val loc_files = slurm_job.job match {
      case ComposeJob(c, f, _, a, p, _, _, _, _, _) => {
        val bit_name = Composer.mkProjectName(c, Target.fromString(a.get.head, p.get.head).get, f)
        val fnames = Seq(bit_name + ".bit", bit_name + ".bit.bin", "timing.txt", "utilization.txt")

        files ++ fnames.map(f => slurm_job.log.resolveSibling(f))
      }
      case HighLevelSynthesisJob(_, a,p, kernels, _) => {
        val tgt = Target.fromString(a.get.head, p.get.head).get
        val cores = kernels.get.map(k => FileAssetManager.entities.core(k, tgt))
        files ++ cores.map(_.get.zipPath) ++ cores.map(_.get.descPath)
      }
      case _ => files
    }
    val remote_files = loc_files map update_paths
    file_transfer(remote_files.zip(loc_files).toMap, tx=false)

    // run postamble script, if specified
    if (slurm_remote_cfg.get.PostambleScript.isDefined)
      "sh %s".format(slurm_remote_cfg.get.PostambleScript.get).!
  }

  /**
    * Copy a set of files either from a host to a remote SLURM node or vice versa, depending on the @param tx
    * @param tfer A map from SRC to DST file paths
    * @param tx indicates the direction of transfer. If value is true (false), the direction is push (pull).
    **/
  def file_transfer(tfer: Map[Path, Path], tx: Boolean): Boolean = {
    for ((from, to) <- tfer) {
      val target_host = slurm_remote_cfg.get.workstation;
      logger.info("Copying %s to %s on %s".format(from, to, target_host))

      // parent directory may not exist
      exec_cmd("mkdir -p %s".format(to.getParent), hostname = Some(target_host))

      val cpy_cmd = if (tx)
        "scp -r %s %s:%s".format(from, target_host, to)
      else
        "scp -r %s:%s %s".format(target_host, from, to)
      logger.info("Copy Command: " + cpy_cmd)
      if (cpy_cmd.! != 0)  throw new Exception("Could not copy file %s to %s!".format(from, to))
    }
    true
  }

  /**
    * Schedules a job on SLURM.
    *
    * @param slurm_job Job script to schedule via `sbatch`.
    * @return Either a positive integer (SLURM id), or an Exception.
    **/
  def apply(slurm_job: Job)(implicit cfg: Configuration): Option[Int] = {
    val local_base = slurm_job.cfg_file.getParent
    val jobFile = local_base.resolveSibling("slurm-job.slurm") // SLURM job script

    /** replace a prefix of a Path by a different prefix. Used to convert local file paths to paths that are valid on SLURM node */
    def prefix_subst(old_pre: Path, new_pre: Path): (Path => Path) = {
      f => {
        val postfix = f.toString.stripPrefix(old_pre.toString).stripPrefix("/")
        new_pre.resolve(postfix)
      }
    }
    val wd_to_rmt   = if (slurm_remote_cfg.isDefined)
      prefix_subst(cfg.kernelDir.getParent, slurm_remote_cfg.get.workdir)
    else identity[Path] _
    val tpsc_to_rmt = if (slurm_remote_cfg.isDefined)
      prefix_subst(cfg.platformDir.getParent.getParent.getParent, slurm_remote_cfg.get.installdir)
    else identity[Path] _

    /** Create non-slurm cfg, with updated paths such that they match the folder structure on SLURM node */
    val newCfg = cfg
      .descPath(wd_to_rmt(cfg.descPath))
      .compositionDir(wd_to_rmt(cfg.compositionDir))
      .coreDir(wd_to_rmt(cfg.coreDir))
      .kernelDir(wd_to_rmt(cfg.kernelDir))
      .platformDir(tpsc_to_rmt(cfg.platformDir))
      .archDir(tpsc_to_rmt(cfg.archDir))
      .jobs(Seq(slurm_job.job))
      .slurm(None)

    logger.info("starting " + slurm_job.name + " job on SLURM ({})", slurm_job.cfg_file)
    catchAllDefault[Option[Int]](None, "error during SLURM job execution (%s): ".format(jobFile)) {
      Files.createDirectories(local_base) // create base directory

      Slurm.writeJobScript(slurm_job, jobFile, wd_to_rmt) // write job script
      Configuration.to(newCfg, slurm_job.cfg_file) // write Configuration to file

      /** preamble: copy required files to SLURM node */
      if (slurm_remote_cfg.isDefined) {
        val files_to_copy = Seq(jobFile, slurm_job.cfg_file)
        slurm_preamble(slurm_job, files_to_copy, wd_to_rmt)
      }

      val cmd = "sbatch %s %s".format(
        slurm_remote_cfg match {
          case Some(c) => c.SbatchOptions
          case None => ""
        },
        wd_to_rmt(jobFile.toAbsolutePath()).normalize().toString
      )
      logger.debug("running slurm batch job: '%s'".format(cmd))

      var id: Option[Int] = None
      var retries = SLURM_RETRIES
      while (id.isEmpty) {
        val res = exec_cmd(cmd)
        id = slurmSubmissionAck.findFirstMatchIn(res) map (_ group (1) toInt)
        if (id.isEmpty) {
          if (retries > 0) {
            // wait for 10 secs + random up to 5 secs to avoid congestion
            Thread.sleep(slurmRetryDelay + scala.util.Random.nextInt() % (slurmRetryDelay / 2))
            retries -= 1
          } else {
            throw new SlurmException(jobFile.toString, res)
          }
        }
      }
      logger.debug("received SLURM id: {}", id)

      /** define postamble that shall be run once job is finished */
      if (slurm_remote_cfg.isDefined) {
        postambles += (id.get -> {slurm_id =>
          logger.info("Running postamble for SLURM id: {}", slurm_id)
          slurm_postamble(slurm_job, Seq(slurm_job.log, slurm_job.slurmLog, slurm_job.errorLog), wd_to_rmt)
        })
      }
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

    // callback that pulls generated files from remote node
    if (slurm_remote_cfg.isDefined)
      postambles(id)(id)
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
      exec_cmd(cmd)
    }
  }

  /** Execute a SLURM command, either locally or on a remote host */
  def exec_cmd(c: String, hostname: Option[String] = None): String = {
    val cmd = if (slurm_remote_cfg.isEmpty) c else {
      val host = hostname.getOrElse(slurm_remote_cfg.get.host)
      "ssh %s %s".format(host, c)
    }

    logger.info("Executing command: %s".format(cmd))
    cmd.!!
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
