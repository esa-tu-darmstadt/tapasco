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
  /** Polling interval for `sacct`. */
  final val slurmDelay = 15000 // 15 secs
  /** Set of POSIX permissions for SLURM job scripts. */
  final val slurmScriptPermissions = Set(OWNER_READ, OWNER_WRITE, OWNER_EXECUTE, GROUP_READ, OTHERS_READ).asJava
  /** Wait interval between retries. */
  final val slurmRetryDelay = 10000 // 10 secs
  /** Stores a closure for every slurm job id, which is called once that job finishes. */
  var postambles: Map[Int, Int => Boolean => Unit] = Map()

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
    if (slurm_remote_cfg.isDefined)
      jobScript("WORKSTATION") = slurm_remote_cfg.get.workstation
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
    * @param update_paths Function that converts local workdir file paths to valid paths on a remote SLURM node.
    **/
  def slurm_preamble(slurm_job: Job, update_paths: Path => Path)(implicit cfg: Configuration): Unit = {
    val local_files = Seq(slurm_job.cfg_file) ++ (slurm_job.job match {
      case ComposeJob(c, _, _, a, p, _, _, _, _, _) => {
        val tgt = Target.fromString(a.get.head, p.get.head).get
        val cores = c.composition.map(ce => FileAssetManager.entities.core(ce.kernel, tgt))
        cores.map(_.get.zipPath) ++ cores.map(_.get.descPath)
      }
      case HighLevelSynthesisJob(_, _, _, k, _) => {
        val kernels = FileAssetManager.entities.kernels.filter( kernel => k.get.contains(kernel.name) ).toSeq
        kernels.map(_.descPath.getParent)
      }
      case _ => Seq()
    })
    val remote_files = local_files map update_paths
    file_transfer(local_files.zip(remote_files).toMap, tx = true)

    // run preamble script, if specified
    slurm_remote_cfg.get.PreambleScript map ("sh %s".format(_).!)
  }

  /**
    * Postamble is run after the SLURM job is finished.
    * Copy generated artefacts back from the SLURM node.
    * @param slurm_job  Job to execute.
    * @param slurm_success  Indicates if the SLURM job finished successfully.
    * @param update_paths Function that converts local workdir file paths to valid paths on a remote SLURM node.
    **/
  def slurm_postamble(slurm_job: Job, slurm_success: Boolean, update_paths: Path => Path): Unit = {
    val loc_files = Seq(slurm_job.log, slurm_job.slurmLog, slurm_job.errorLog) ++ (slurm_job.job match {
      case ComposeJob(c, f, _, a, p, _, _, _, _, _) if slurm_success => {
        val bit_name = Composer.mkProjectName(c, Target.fromString(a.get.head, p.get.head).get, f)
        val fnames = Seq(bit_name + ".bit", bit_name + ".bit.bin", "timing.txt", "utilization.txt")
        fnames.map(f => slurm_job.log.resolveSibling(f))
      }
      case HighLevelSynthesisJob(_, a,p, kernels, _) if slurm_success => {
        val tgt = Target.fromString(a.get.head, p.get.head).get
        val core_dir = slurm_job.log.getParent.resolveSibling("ipcore")
        val core_zip = kernels.get.map(k => core_dir.resolve("%s.zip".format(k)))
        core_zip ++ core_zip.map(z => z.resolveSibling("core.json"))
      }
      case _ => Seq()
    })
    val remote_files = loc_files map update_paths
    file_transfer(remote_files.zip(loc_files).toMap, tx=false)

    // run postamble script, if specified
    slurm_remote_cfg.get.PostambleScript map ("sh %s".format(_).!)
  }

  /**
    * Copy a set of files either from a host to a remote SLURM node or vice versa, depending on the @param tx
    * @param tfer A map from SRC to DST file paths
    * @param tx indicates the direction of transfer. If value is true (false), the direction is push (pull).
    **/
  def file_transfer(tfer: Map[Path, Path], tx: Boolean, host: Option[String] = None): Boolean = {
    for ((from, to) <- tfer) {
      val target_host = host.getOrElse(slurm_remote_cfg.get.workstation)
      logger.info("Copying %s to %s on %s".format(from, to, target_host))

      // parent directory may not exist
      val mkdir = "mkdir -p %s".format(to.getParent)
      if (tx) exec_cmd(mkdir, hostname = Some(target_host)) else mkdir.!

      val cpy_cmd = if (tx) {
        "scp -r %s %s:%s".format(from, target_host, to)
      } else {
        "scp -r %s:%s %s".format(target_host, from, to)
      }
      logger.debug("Copy Command: " + cpy_cmd)
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
    val jobFile = local_base.resolveSibling("%s.slurm".format(slurm_job.name)) // SLURM job script

    /** replace a prefix of a Path by a different prefix. Used to convert local file paths to paths that are valid on SLURM node */
    def prefix_subst(old_pre: Path, new_pre: Path): (Path => Path) = {
      f => {
        val postfix = f.toString.stripPrefix(old_pre.toString).stripPrefix("/")
        new_pre.resolve(postfix)
      }
    }
    val (wd_to_rmt, tpsc_to_rmt) = if (slurm_remote_cfg.isDefined)
      (prefix_subst(cfg.kernelDir.getParent, slurm_remote_cfg.get.workdir),
       prefix_subst(cfg.platformDir.getParent.getParent.getParent, slurm_remote_cfg.get.installdir))
    else (identity[Path] _, identity[Path] _)

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
        // copy all required files to workstation
        slurm_preamble(slurm_job, wd_to_rmt)

        // copy slurm job file to slurm login node
        file_transfer(Map(jobFile -> Paths.get("~/%s.slurm".format(slurm_job.name))),
                      tx = true, host=Some(slurm_remote_cfg.get.host))
      }

      val cmd = "sbatch " ++ (slurm_remote_cfg match {
          case Some(c) => "%s ~/%s.slurm".format(c.SbatchOptions, slurm_job.name)
          case None => jobFile.toAbsolutePath().normalize().toString
        })
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
        postambles += (id.get -> {slurm_id:Int => slurm_success:Boolean =>
          logger.info("Running postamble for SLURM id: {}", slurm_id)
          slurm_postamble(slurm_job, slurm_success, wd_to_rmt)
        })
      }
      id
    }
  }

  /** Check via `sacct` if the SLURM job is still running. */
  def getSlurmStatus(id: Int): SlurmStatus = catchAllDefault[SlurmStatus](Unknown(), "Slurm `sacct` failed: ") {
    val sacct = exec_cmd("sacct -pn")
    val pattern = """%d\|([^|]*)\|[^|]*\|[^|]*\|[^|]*\|([A-Z]*)( [^|]*)?\|[^|]*\|""".format(id).r
    pattern.findFirstIn(sacct) match {
      case None =>
        logger.warn("Job ID %d not listed in sacct".format(id))
        Slurm.Unknown()
      case Some(m) => m match {
        case pattern(name, status, cancelledBy) => status match {
          case "RUNNING" => Slurm.Running ()
          case "COMPLETED" => Slurm.Completed ()
          case "CANCELLED" => Slurm.Cancelled (cancelledBy)
          case _ =>
            logger.warn ("Job %s (ID=%d) has status %s".format (name, id, status) )
            Slurm.Unknown ()
        }
      }
    }
  }

  /** Wait until the given SLURM job is not listed as RUNNING anymore in `sacct` output. */
  def waitFor(id: Int): SlurmStatus = {
    var status: SlurmStatus = Slurm.Running()
    while (status == Running()) {
      logger.info("SLURM job #%d is still running, sleeping for %d secs ...".format(id, slurmDelay / 1000))
      Thread.sleep(slurmDelay)
      status = getSlurmStatus(id)
    }

    // callback that pulls generated files from remote node
    if (slurm_remote_cfg.isDefined)
      postambles(id)(id)(status == Slurm.Completed())
    status
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

    logger.debug("Executing command: %s".format(cmd))
    cmd.!!
  }

  /** Use SLURM? */
  private var _enabled = false

  /** Host for executing SLURM */
  private var slurm_remote_cfg: Option[SlurmRemoteConfig] = None

  sealed trait SlurmStatus
  final case class Completed() extends SlurmStatus
  final case class Cancelled(by: String) extends SlurmStatus
  final case class Running() extends SlurmStatus
  final case class Unknown() extends SlurmStatus

  sealed trait SlurmConfig
  final case class EnabledLocal() extends SlurmConfig
  final case class EnabledRemote(template_name: String) extends SlurmConfig
  final case class Disabled() extends SlurmConfig
}
