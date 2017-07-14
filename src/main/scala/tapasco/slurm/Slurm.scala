package de.tu_darmstadt.cs.esa.tapasco.slurm
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.task.ResourceConsumer
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.util.{Publisher, Template}
import  scala.collection.JavaConverters._
import  scala.sys.process._
import  java.nio.file._
import  java.nio.file.attribute.PosixFilePermission._

/**
 * Primitive interface to SLURM scheduler:
 * Can be used to generate job scripts and schedule them on SLURM via `sbatch`.
 * Provides methods to write the script, schedule and wait for it.
 **/
final object Slurm extends Publisher {
  private implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /** Model of a SLURM job. */
  final case class Job(
    /** Name of the job. */
    name: String,
    /** File name of the stdout logfile. */
    slurmLog: String,
    /** File name of the stderr logfile. */
    errorLog: String,
    /** Consumer to schedule. */
    consumer: ResourceConsumer,
    /** Time limit (in hours). */
    maxHours: Int,
    /** Sequence of commands to execute (bash). */
    commands: Seq[String],
    /** Optional comment. */
    comment: Option[String] = None
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
  final val slurmSubmissionAck = """[Ss]ubmitted batch job (\d+)""".r
  /** Polling interval for `squeue`. */
  final val slurmDelay = 15000 // 15 secs
  /** Set of POSIX permissions for SLURM job scripts. */
  final val slurmScriptPermissions = Set(OWNER_READ, OWNER_WRITE, OWNER_EXECUTE, GROUP_READ, OTHERS_READ).asJava

  /** Returns true if SLURM is available on host running iTPC. */
  lazy val available: Boolean = "which sbatch".! == 0

  /** Returns true, if SLURM is available and enabled. */
  def enabled: Boolean = Slurm.synchronized { _enabled }
  /** Enables or disables SLURM, returns new value for enabled. */
  def enabled_=(en: Boolean): Boolean = if (en && available) {
    Slurm.synchronized { _enabled = en }
    publish(Events.SlurmModeEnabled(en))
    enabled
  } else {
    if (en) {
      logger.warn("SLURM mode was selected, but could be not activated (sbatch not found)")
    }
    false
  }

  /** Helper function: Sets correct file permissions on job scripts. */
  def setScriptPermissions(script: Path): Unit = Files.setPosixFilePermissions(script, slurmScriptPermissions)

  /**
   * Write a SLURM job script to given file.
   * @param job Job to execute.
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
   * @param script Job script file to schedule via `sbatch`.
   * @return Either a positive integer (SLURM id), or an Exception.
   **/
  def apply(script: Path, retries: Int = 3): Option[Int] = catchAllDefault[Option[Int]](None, "Slurm scheduling failed: ") {
    val cmd = "sbatch %s".format(script.toAbsolutePath().normalize().toString)
    logger.debug("running slurm batch job: '%s'".format(cmd))
    val res = cmd.!!
    val id = slurmSubmissionAck.findFirstMatchIn(res) map (_ group (1) toInt)
    if (id.isEmpty ) {
      if (retries > 0) {
        Thread.sleep(10000) // wait 10 secs
        apply(script, retries - 1)
      } else throw new SlurmException(script.toString, res)
    } else {
      logger.debug("received SLURM id: {}", id)
      id
    }
  }

  /** Check via `squeue` if the SLURM job is still running. */
  def isRunning(id: Int): Boolean = catchAllDefault[Boolean](true, "Slurm `squeue` failed: ") {
    val squeue = "squeue -h".!!
    logger.trace("squeue output: {}", squeue)
    ! "%d".format(id).r.findFirstIn(squeue).isEmpty
  }

  /** Wait until the given SLURM job disappears from `squeue` output. */
  def waitFor(id: Int): Unit = {
    while (isRunning(id)) {
      logger.trace("SLURM job #%d is still running, sleeping for %d secs ...".format(id, slurmDelay / 1000))
      Thread.sleep(slurmDelay)
    }
  }

  /** Returns a list of all SLURM job ids which are registered under the
   *  the current user's account. */
  def jobs(): Seq[Int] = if (! enabled) { Seq() } else {
    catchAllDefault(Seq[Int](), "could not get squeue output: ") {
      val lines = "squeue -u %s".format(sys.env("USER")).!!
      val ids = ("""\n\s*(\d+)""".r.unanchored.findAllMatchIn(lines) map (m => m.group(1).toInt)).toSeq
      logger.debug("running SLURM jobs: {}", ids mkString " ")
      ids
    }
  }

  /** Cancels the SLURM job with the given ID. */
  def cancel(id: Int): Unit = catchAllDefault((), "canceling SLURM job %d failed: ".format(id)) {
    "scancel %d".format(id).!!
  }

  /** Cancels all currently running SLURM jobs. */
  def cancelAllJobs(): Unit = catchAllDefault((), "canceling SLURM jobs failed: ") {
    val ids = jobs()
    if (ids.length > 0) {
      val cmd = "scancel %s" format (ids mkString " ")
      logger.info("canceling SLURM jobs: {}", ids mkString ", ")
      logger.debug("command: '{}'", cmd)
      cmd.!
    }
  }

  /** Use SLURM? */
  private var _enabled = false
}
