package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.json._
import  play.api.libs.json._
import  scala.io.Source
import  java.nio.file._
import  fastparse.all._

private object GlobalOptions {
  import BasicParsers._

  def validOption: Parser[String] = (
    longShortOption("h", "help")    |
    longShortOption("v", "verbose") |
    longShortOption("n", "dryRun")  |
    longOption("archDir")           |
    longOption("platformDir")       |
    longOption("coreDir")           |
    longOption("compositionDir")    |
    longOption("kernelDir")         |
    longOption("jobsFile")          |
    longOption("configFile")        |
    longOption("logFile")           |
    longOption("parallel")          |
    longOption("slurm")             |
    longOption("maxThreads") 
  ).opaque("a global option")

  def help: Parser[(String, String)] =
    (longShortOption("h", "help") | IgnoreCase("help") | IgnoreCase("usage")) ~
    (ws1 ~ string).? map { case (h, topic) => { Usage.topic(topic); ("Help", Usage()) } }

  def verbose: Parser[(String, String)] =
    (longShortOption("v", "verbose", Some("Verbose")) ~/ (ws1 ~ quotedString.opaque("verbose mode as quoted string")).? ~ ws)
      .map { case (k, mode) => (k, mode getOrElse "verbose") }

  def archDir: Parser[(String, Path)] =
    longOption("archDir", "Architecture") ~/ ws1 ~ path.opaque("root dir of Architectures") ~ ws
  def platformDir: Parser[(String, Path)] =
    longOption("platformDir", "Platform") ~/ ws1 ~ path.opaque("root dir of Platforms") ~ ws
  def coreDir: Parser[(String, Path)] =
    longOption("coreDir", "Core") ~/ ws1 ~ path.opaque("root dir of Cores") ~ ws
  def compositionDir: Parser[(String, Path)] =
    longOption("compositionDir", "Composition") ~/ ws1 ~ path.opaque("root dir of Compositions") ~ ws
  def kernelDir: Parser[(String, Path)] =
    longOption("kernelDir", "Kernel") ~/ ws1 ~ path.opaque("root dir of Kernels") ~ ws

  def jobsFile: Parser[(String, Path)] =
    longOption("jobsFile", "JobsFile") ~/ ws1 ~ path.opaque("path to .json file with jobs array") ~ ws

  def configFile: Parser[(String, Path)] =
    longOption("configFile", "ConfigFile") ~/ ws1 ~ path.opaque("path to .json file with config") ~ ws

  def logFile: Parser[(String, Path)] =
    longOption("logFile", "LogFile") ~ ws ~/ path.opaque("path to logfile") ~ ws

  def dirs: Parser[(String, Path)] =
    archDir | platformDir | kernelDir | compositionDir | coreDir
  def inputFiles: Parser[(String, Path)] =
    jobsFile | configFile | logFile

  def slurm: Parser[(String, Boolean)] =
    longOption("slurm", "Slurm").map((_, true)) ~ ws

  def parallel: Parser[(String, Boolean)] =
    longOption("parallel", "Parallel").map((_, true)) ~ ws

  def dryRun: Parser[(String, Path)] =
    longShortOption("n", "dryRun") ~/ ws ~ path.opaque("output file name") ~/ ws map {
      case (_, p) => ("DryRun", p)
    }

  def maxThreads: Parser[(String, Int)] =
    longOption("maxThreads", "MaxThreads") ~/ ws ~ posint ~ ws

  def globalOptionsSeq: Parser[Seq[(String, _)]] =
    ws ~ (help | verbose | dirs | inputFiles | slurm | parallel | dryRun | maxThreads).rep

  def globalOptions: Parser[Configuration] =
    globalOptionsSeq map (as => mkConfig(as))

  private def mkConfig[A <: Seq[Tuple2[String, _]]](pa: A, c: Option[Configuration] = None): Configuration =
    pa match {
      case a +: as => a match {
        case ("Architecture", p: Path) => mkConfig(as, Some(c getOrElse Configuration() archDir p))
        case ("Composition", p: Path)  => mkConfig(as, Some(c getOrElse Configuration() compositionDir p))
        case ("Core", p: Path)         => mkConfig(as, Some(c getOrElse Configuration() coreDir p))
        case ("Kernel", p: Path)       => mkConfig(as, Some(c getOrElse Configuration() kernelDir p))
        case ("Platform", p: Path)     => mkConfig(as, Some(c getOrElse Configuration() platformDir p))
        case ("Slurm", e: Boolean)     => mkConfig(as, Some(c getOrElse Configuration() slurm e))
        case ("Parallel", e: Boolean)  => mkConfig(as, Some(c getOrElse Configuration() parallel e))
        case ("JobsFile", p: Path)     => mkConfig(as, Some(c getOrElse Configuration() jobs readJobsFile(p)))
        case ("LogFile", p: Path)      => mkConfig(as, Some(c getOrElse Configuration() logFile Some(p)))
        case ("ConfigFile", p: Path)   => mkConfig(as, Some(loadConfigFromFile(p)))
        case ("DryRun", p: Path)       => mkConfig(as, Some(c getOrElse Configuration() dryRun Some(p)))
        case ("MaxThreads", i: Int)    => mkConfig(as, Some(c getOrElse Configuration() maxThreads Some(i)))
        case ("Verbose", m: String)    => mkConfig(as, Some(c getOrElse Configuration() verbose Some(m)))
        case _                         => c getOrElse Configuration()
      }
      case x => c getOrElse Configuration()
    }

  private def readJobsFile(p: Path): Seq[Job] =
    Json.fromJson[Seq[Job]](Json.parse(Source.fromFile(p.toString).getLines mkString "")) match {
      case s: JsSuccess[Seq[Job]] => s.get
      case e: JsError => throw new Exception(e.toString)
    }

  private def loadConfigFromFile(p: Path): Configuration = Configuration.from(p) match {
    case Right(c) => c
    case Left(e)  => throw e
  }
}
