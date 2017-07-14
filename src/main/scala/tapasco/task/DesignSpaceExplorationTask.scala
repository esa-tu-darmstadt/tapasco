package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.Composer
import  de.tu_darmstadt.cs.esa.tapasco.dse.{DesignSpace, Heuristics}
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.LogFileTracker
import  java.nio.file.Paths

/** Interface for design space exploration tasks. */
trait ExplorationTask extends Task {
  /** Returns the design space exploration object. */
  def exploration: Exploration
}

/**
 * Internal implementation of the design space exploration task.
 * @param m Model to associate with.
 * @param logFile File name for main log file of this DSE.
 * @param onComplete Callback function on completion.
 **/
private class DesignSpaceExplorationTask(
    composition: Composition,
    target: Target,
    dimensions: DesignSpace.Dimensions,
    designFrequency: Heuristics.Frequency,
    heuristic: Heuristics.Heuristic,
    batchSize: Int,
    basePath: Option[String],
    features: Option[Seq[Feature]],
    logFile: Option[String],
    debugMode: Option[String],
    val onComplete: Boolean => Unit)
    (implicit cfg: Configuration, tsk: Tasks) extends Task with LogTracking with ExplorationTask {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  /** Internal representation of result. **/
  private[this] var _result: Option[(DesignSpace.Element, Composer.Result)] = None
  private[this] val _bp = basePath map (p => Paths.get(p).toAbsolutePath) getOrElse {
    val shortDate = java.time.format.DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(java.time.LocalDateTime.now())
    val dsepath = FileAssetManager.TAPASCO_HOME.resolve(
      "DSE_%s".format(shortDate).replace(" ", "_").replace("/", "-").replace(":","-")
    ).normalize()
    java.nio.file.Files.createDirectories(dsepath.resolve("bd"))
    dsepath
  }
  // use implicit Configuration via UserConfigurationModel
  private implicit val _cfg: Configuration = cfg.compositionDir(_bp.resolve("bd"))

  /** @inheritdoc */
  val exploration = Exploration(
    composition,
    dimensions,
    target,
    designFrequency,
    batchSize,
    _bp,
    debugMode
  )(_cfg, tsk)

  /**
   * Launches the design space exploration.
   **/
  def job: Boolean = {
    // flag dse as running
    DesignSpaceExplorationTask.started(this)
    // setup a log file appender to log progress
    val appender = logFile map { LogFileTracker.setupLogFileAppender _ }
    try {
      // internal logfile is located in subdirectory for this exploration
      val logfile = new ExplorationLog
      exploration += logfile
      // run DSE (this may take a while)
      val result = exploration.start()
      // fetch result, if any
      _result = result map { r => (r._1, r._2) }
      // flush and close the logfile
      ExplorationLog.toFile(logfile, "%s/dse.json".format(exploration.basePath))(_cfg)
      // log the result
      _logger.info("DSE%s run %s for %s finished, result: %s;{}".format(dimensions, composition, target, result.nonEmpty),
          result map ( res =>
            (" best result: %s @ %1.3f, bitstream file: '%s', logfile: '%s', utilization report: '%s', " +
            "timing report: '%s', power report: '%s'").format(
              res._1.composition,
              res._1.frequency,
              res._2.bit getOrElse "",
              res._2.log map (_.file) getOrElse "",
              res._2.util map (_.file) getOrElse "",
              res._2.timing map (_.file) getOrElse "",
              res._2.power map (_.file) getOrElse "")) getOrElse "")
      // return success, if result is not empty
      result.nonEmpty
    } catch { case ex: Throwable =>
      _logger.error("exception: {}, stacktrace: {}", ex: Any, ex.getStackTrace mkString "\n": Any)
      false
    } finally {
      FileAssetManager.start()
      DesignSpaceExplorationTask.finished(this)
      // stop logfile appender
      appender map { LogFileTracker.stopLogFileAppender _ }
    }
  }

  override def canStart: Boolean = ! DesignSpaceExplorationTask.running

  /** @inheritdoc */
  def description: String = "Design Space Exploration"
  /** @inheritdoc */
  def logFiles: Set[String] = Set(logFile.toString)
  /** Result of the design space exploration: the 'winner'. */
  def explorationResult: Option[(DesignSpace.Element, Composer.Result)] = _result
  // Resources for scheduling: None
  val cpus = 0
  val memory = 0
  val licences = Map[String, Int]()
}

/**
 * Companion object for DesignSpaceExplorationTask: Factory method.
 **/
object DesignSpaceExplorationTask {
  /** Currently running instance of task. **/
  private var _task: Option[DesignSpaceExplorationTask] = None

  /** Notification that the given DSE task has started. */
  private def started(t: DesignSpaceExplorationTask) = _task.synchronized {
    require(_task.isEmpty, "must not launch multiple DSEs at once")
    _task = Some(t)
  }

  /** Returns true, if a DSE task is currently running. */
  private def running: Boolean = _task.synchronized { _task.nonEmpty }

  /** Notification that the given DSE task has finished. */
  private def finished(t: DesignSpaceExplorationTask) = _task.synchronized {
    assert(t.equals(_task.get))
    _task = None
  }

  // scalastyle:off parameter.number
  def apply(composition: Composition,
            target: Target,
            dimensions: DesignSpace.Dimensions,
            designFrequency: Heuristics.Frequency,
            heuristic: Heuristics.Heuristic,
            batchSize: Int,
            basePath: Option[String],
            features: Option[Seq[Feature]],
            logFile: Option[String],
            debugMode: Option[String],
            onComplete: Boolean => Unit)
           (implicit cfg: Configuration, tsk: Tasks): ExplorationTask = {
    new DesignSpaceExplorationTask(
        composition,
        target,
        dimensions,
        designFrequency,
        heuristic,
        batchSize,
        basePath,
        features,
        logFile,
        debugMode,
        onComplete)
  }
  // scalastyle:on parameter.number
}
