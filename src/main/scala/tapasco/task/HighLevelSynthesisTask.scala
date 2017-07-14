package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.activity.hls._
import  de.tu_darmstadt.cs.esa.tapasco.activity.hls.HighLevelSynthesizer.Implementation
import  de.tu_darmstadt.cs.esa.tapasco.activity.hls.HighLevelSynthesizer._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.HighLevelSynthesisJob
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  java.nio.file._

class HighLevelSynthesisTask(val k: Kernel, val t: Target, val cfg: Configuration, hls: Implementation,
    val onComplete: Boolean => Unit) extends Task with LogTracking {
  private[this] implicit val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] var result: Option[HighLevelSynthesizer.Result] = None
  private[this] val slurm = Slurm.enabled
  private[this] val r = HighLevelSynthesizer(hls)
  private[this] val l = r.logFile(k, t)(cfg).resolveSibling("hls.log")
  private[this] val e = l.resolveSibling("hls-slurm.errors.log")

  def synthesizer: HighLevelSynthesizer = r

  def synthesisResult: Option[HighLevelSynthesizer.Result] = result

  def description: String =
    "High-Level-Synthesis for '%s' with target %s @ %s".format(k.name, t.pd.name, t.ad.name)

  def job: Boolean = if (! slurm) {
    val appender = LogFileTracker.setupLogFileAppender(l.toString)
    logger.trace("current thread name: {}", Thread.currentThread.getName())
    result = Some(r.synthesize(k, t)(cfg))
    LogFileTracker.stopLogFileAppender(appender)
    result map (_.toBoolean) getOrElse false
  } else {
    val cfgFile  = l.resolveSibling("slurm-hls.cfg")  // Configuration Json
    val jobFile  = l.resolveSibling("hls.slurm")      // SLURM job script
    val slurmLog = l.resolveSibling("slurm-hls.log") // raw log file (stdout w/colors)
    val hlsJob   = HighLevelSynthesisJob(hls.toString, Some(Seq(t.ad.name)), Some(Seq(t.pd.name)), Some(Seq(k.name)))
    // define SLURM job
    val job = Slurm.Job(
      name     = "hls-%s-%s-%s".format(t.ad.name, t.pd.name, k.name),
      slurmLog = slurmLog.toString,
      errorLog = e.toString,
      consumer = this,
      maxHours = HighLevelSynthesisTask.MAX_SYNTH_HOURS,
      commands = Seq("tapasco --configFile %s".format(cfgFile.toString, k.name.toString))
    )
    // generate non-SLURM config with single job
    val newCfg = cfg
      .logFile(Some(l))
      .jobs(Seq(hlsJob))
      .slurm(false)

    logger.info("starting HLS job on SLURM ({})", cfgFile)

    catchAllDefault(false, "error during SLURM job execution (%s): ".format(jobFile)) {
      Files.createDirectories(l.getParent())                    // create base directory
      Slurm.writeJobScript(job, jobFile)                        // write job script
      Configuration.to(newCfg, cfgFile)                         // write Configuration to file
      val r = (Slurm(jobFile) map (Slurm.waitFor(_))).nonEmpty  // execute sbatch to enqueue job, then wait for it
      FileAssetManager.reset()
      r
    }
  }
  def logFiles: Set[String] = Set(l.toString)
  // resource requirements
  val cpus = 1
  val memory = 4 * 1024 * 1024
  val licences = Map(
    "HLS"                   -> 1,
    "Synthesis"             -> 1,
    "Implementation"        -> 1,
    "Vivado_System_Edition" -> 1
  )
}

private object HighLevelSynthesisTask {
  final val MAX_SYNTH_HOURS = 8
}
