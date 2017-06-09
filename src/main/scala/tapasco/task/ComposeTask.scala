package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers._
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.dse.Heuristics
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.LogFileTracker
import  java.nio.file._
import  scala.util.Properties.{lineSeparator => NL}

/**
 * ComposeTask executes a single composition execution with a Composer.
 * It will run the composition tool (e.g., Xilinx Vivado) as a separate process
 * and return the result (see [[activity.composers]]).
 **/
class ComposeTask(composition: Composition,
                  designFrequency: Heuristics.Frequency,
                  implementation: Composer.Implementation,
                  target: Target,
                  features: Option[Seq[Feature]] = None,
                  logFile: Option[String] = None,
                  debugMode: Option[String] = None,
                  val onComplete: Boolean => Unit)
                 (implicit cfg: Configuration) extends Task with LogTracking {
  private[this] implicit val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _slurm = Slurm.enabled
  private[this] var _composerResult: Option[Composer.Result] = None
  private[this] val _outDir = cfg.outputDir(composition, target, designFrequency)
  private[this] val _logFile = logFile getOrElse "%s/%s.log".format(_outDir, "tapasco")
  private[this] val _errorLogFile = Paths.get(_logFile).resolveSibling("slurm-compose.errors.log")

  import LogFormatter._

  def composerResult: Option[Composer.Result] = _composerResult

  /** @inheritdoc **/
  def job: Boolean = if (! _slurm) nodeExecution else slurmExecution

  private def nodeExecution: Boolean = {
    val appender = LogFileTracker.setupLogFileAppender(_logFile.toString)
    val composer = Composer(implementation)(cfg)
    _logger.debug("launching compose run for {}@{} [current thread: {}], logfile {}",
      target.ad.name: Object, target.pd.name: Object, Thread.currentThread.getName(): Object, _logFile: Object)
    if (debugMode.isEmpty) {
      _composerResult = Some(try   { composer.compose(composition, target, designFrequency, Seq(), features getOrElse Seq()) }
                             catch { case e: Exception =>
                                       _logger.error(e.toString)
                                       _logger.debug("stacktrace: {}", e.getStackTrace() mkString NL)
                                       Composer.Result(e)
                                   })
    } else {
      _composerResult = ComposeTask.makeDebugResult(debugMode.get)
    }

    _logger.trace("_composerResult = {}", _composerResult: Any)
    _logger.info(("compose run %s@%2.3f MHz for %s finished, result: %s, bitstream file: '%s', " +
        "logfile: '%s', utilization report: '%s', timing report: '%s', power report: '%s'").format(
        composition: Any,
        designFrequency,
        target,
        _composerResult map (_.result) getOrElse "",
        _composerResult map (_.bit) getOrElse "",
        _composerResult flatMap (_.log map (_.file)) getOrElse "",
        _composerResult flatMap (_.util map (_.file)) getOrElse "",
        _composerResult flatMap (_.timing map (_.file)) getOrElse "",
        _composerResult flatMap (_.power map (_.file)) getOrElse ""))

    LogFileTracker.stopLogFileAppender(appender)
    val result = (_composerResult map (_.result) getOrElse false) == ComposeResult.Success
    if (result)
      composer.clean(composition, target, designFrequency)
    result
  }

  private def slurmExecution: Boolean = {
    val l = Paths.get(_logFile).toAbsolutePath().normalize()
    val cfgFile = l.resolveSibling("slurm-compose.cfg")   // Configuration Json
    val jobFile = l.resolveSibling("slurm-compose.slurm") // SLURM job script
    val slgFile = l.resolveSibling("slurm-compose.log")   // SLURM job stdout log
    val cmpsJob = ComposeJob(
      composition, designFrequency, implementation.toString, Some(Seq(target.ad.name)), Some(Seq(target.pd.name)),
      features, debugMode
    )
    // define SLURM job
    val job = Slurm.Job(
      name     = "compose-%s-%s-%s-%1.2f".format(composition.id, target.ad.name, target.pd.name, designFrequency),
      slurmLog = slgFile.toString,
      errorLog = _errorLogFile.toString,
      consumer = this,
      maxHours = ComposeTask.MAX_COMPOSE_HOURS,
      commands = Seq("tapasco --configFile %s".format(cfgFile.toString)),
      comment  = Some("%s".format(composition.composition map (ce => "%s % d".format(ce.kernel, ce.count)) mkString ", "))
    )
    // generate non-SLURM config with single job
    val newCfg = cfg
      .logFile(Some(l))
      .slurm(false)
      .jobs(Seq(cmpsJob))

    _logger.info("launching Compose job on SLURM ({})", cfgFile)

    catchAllDefault(false, "error during SLURM job execution (%s): ".format(jobFile)) {
      Files.createDirectories(jobFile.getParent())              // create base directory
      Slurm.writeJobScript(job, jobFile)                        // write job script
      Configuration.to(newCfg, cfgFile)                         // write Configuration to file
      Slurm(jobFile) foreach (Slurm.waitFor(_))                 // execute and wait
      _composerResult = if (debugMode.isEmpty) {
        ComposeTask.parseResultInLog(l.toString)
      } else {
        ComposeTask.makeDebugResult(debugMode.get)
      }
      (_composerResult map (_.result) getOrElse false) == ComposeResult.Success
    }
  }

  private def elementdesc = "%s [F=%2.2f]".format(logformat(composition), designFrequency.toDouble)

  /** @inheritdoc */
  def description: String = "Compose: %s for %s".format(elementdesc, target)

  /** @inheritdoc */
  def logFiles: Set[String] = Set(_logFile.toString)

  // Resources for scheduling: one CPU per run, memory as per Xilinx website
  val cpus = debugMode map { _ => 0 } getOrElse 1

  val memory = debugMode map { _ => 0 } getOrElse (target.pd.name match {
    case "vc709"    => 32 * 1024 * 1024
    case "zc706"    => 28 * 1024 * 1024
    case "zedboard" => 20 * 1024 * 1024
    case "pynq"     => 20 * 1024 * 1024
    case _          => 32 * 1024 * 1024
  })

  val licences = debugMode map { _ => Map[String, Int]() } getOrElse Map(
    "Synthesis"             -> 1,
    "Implementation"        -> 1,
    "Vivado_System_Edition" -> 1
  )
}

object ComposeTask {
  import scala.io._
  import de.tu_darmstadt.cs.esa.tapasco.reports._
  private final val MAX_COMPOSE_HOURS = 48
  private final val RE_RESULT = """compose run .*result: ([^,]+)""".r.unanchored
  private final val RE_LOG    = """compose run .*result: \S+.*logfile: '([^']+)'""".r.unanchored
  private final val RE_TIMING = """compose run .*result: \S+.*timing report: '([^']+)'""".r.unanchored
  private final val RE_POWER  = """compose run .*result: \S+.*power report: '([^']+)'""".r.unanchored
  private final val RE_UTIL   = """compose run .*result: \S+.*utilization report: '([^']+)'""".r.unanchored
  private final val RE_RRANDOM = """(?i)(random|r(?:nd)?)""".r
  private final val RE_RPLACER = """(?i)(placer|p(?:lc)?)""".r
  private final val RE_RTIMING = """(?i)(timing|t(?:mg)?)""".r
  private final val RE_RSUCCES = """(?i)(s(?:uccess)?)""".r

  def parseResultInLog(log: String)(implicit logger: Logger): Option[Composer.Result] =
    catchDefault (None: Option[Composer.Result], Seq(classOf[java.io.IOException]), "failed to read log %s: ".format(log)) {
      logger.debug("reading log {} @ {}", log)
      val lines: String = Source.fromFile(log).getLines mkString " "
      def mkpath(m: scala.util.matching.Regex.Match): Path = Paths.get(m.group(1))
      val result = RE_RESULT.findFirstMatchIn(lines) flatMap (m => {
        logger.trace("result group: '{}'", m.group(1))
        ComposeResult(m.group(1))
      })
      val llog = RE_LOG.findFirstMatchIn(lines) flatMap (m      => {
        logger.trace("log path: {}", mkpath(m))
        ComposerLog(mkpath(m))
      })
      val power = RE_POWER.findFirstMatchIn(lines) flatMap (m   => {
        logger.trace("power path: {}", mkpath(m))
        PowerReport(mkpath(m))
      })
      val util = RE_UTIL.findFirstMatchIn(lines) flatMap (m   => {
        logger.trace("utilization path: {}", mkpath(m))
        UtilizationReport(mkpath(m))
      })
      val timing = RE_TIMING.findFirstMatchIn(lines) flatMap (m => {
        logger.trace("timing path: {}", mkpath(m))
        TimingReport(mkpath(m))
      })
      logger.debug("result = {}, llog = {}, power = {}, util = {}, timing = {}", result, llog, power, util, timing)
      result map (r => Composer.Result(r, log = llog, power = power, util = util, timing = timing))
    }

  // scalastyle:off magic.number
  private def genPlacerError: Option[Composer.Result] = {
    // generate placer error
    Some(Composer.Result(ComposeResult.PlacerError))
  }

  private def genTimingFailure: Option[Composer.Result] = {
    // generate random timing failure
    Some(Composer.Result(ComposeResult.TimingFailure,
      timing = Some(TimingReport(
        file = java.nio.file.Paths.get("feckedyfeck"),
        worstNegativeSlack = -scala.util.Random.nextInt(500) / 100.0,
        dataPathDelay = 0,
        maxDelayPath = TimingReport.TimingPath("your brain", "your mouth", -42),
        minDelayPath = TimingReport.TimingPath("your ass", "your mouth", 3),
        timingMet = false
    ))))
  }

  private def genSuccess: Option[Composer.Result] = {
    // generate success
    Some(Composer.Result(ComposeResult.Success))
  }

  private def genOtherError: Option[Composer.Result] = {
    // generate misc error
    Some(Composer.Result(ComposeResult.OtherError))
  }

  private def genRandomResult: Option[Composer.Result] = {
    Thread.sleep(3000 + scala.util.Random.nextInt(4000))
    scala.util.Random.nextInt(1000) match {
      case n if n > 500 => genPlacerError
      case n if n >  30 => genTimingFailure
      case _            => genSuccess
    }
  }
  // scalastyle:on magic.number

  private def makeDebugResult(debugMode: String): Option[Composer.Result] = debugMode.toLowerCase match {
    case RE_RPLACER(_) => genPlacerError
    case RE_RTIMING(_) => genTimingFailure
    case RE_RSUCCES(_) => genSuccess
    case RE_RRANDOM(_) => genRandomResult
    case _             => genOtherError
  }
}
