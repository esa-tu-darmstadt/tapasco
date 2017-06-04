package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.json._
import  play.api.libs.json._
import  scala.io.Source
import  java.nio.file.Paths

private object ConfigurationParser {
  import CommandLineParser._

  /** Returns a parser for a Configuration. */
  def apply(): Parser[Configuration] = all

  /* @{ Configuration */
  private def all: Parser[Configuration] = phrase(allArgs) ^^ { p => makeCfg(p._1, p._2) }

  private def allArgs: Parser[(Map[String, String], Seq[Job])] =
    configArgs ~ JobsParser() ^^ { p => (p._1.toMap, p._2) }

  private def configArgs: Parser[Seq[(String, String)]] = rep(
    logFile    ^^ { p => ("LogFile", p) }        |
    configFile ^^ { p => ("ConfigFile", p) }     |
    entityDir  ^^ { p => (p._1.toString, p._2) } |
    slurm      ^^ { p => (p._1, p._2.toString) } |
    parallel   ^^ { p => (p._1, p._2.toString) } |
    jobsFile   ^^ { p => ("JobsFile", p) }
  )

  private def readJobsFile(p: String): Seq[Job] =
    Json.fromJson[Seq[Job]](Json.parse(Source.fromFile(p).getLines mkString "")) match {
      case s: JsSuccess[Seq[Job]] => s.get
      case e: JsError => throw new Exception(e.toString)
    }

  private def makeCfg(m: Map[String, String], jobs: Seq[Job]): Configuration = {
    logger.debug("configuration map: {}", m)
    import scala.util.Properties.{lineSeparator => NL}
    val cfgFromFile = m.get("ConfigFile") map (p => Configuration.from(Paths.get(p).toAbsolutePath))
    cfgFromFile foreach { res =>
      logger.debug("parser result: {}", res)
      res.swap foreach { e => logger.trace("parser stack trace: {}", e.getStackTrace() mkString NL); throw e }
    }
    var c = cfgFromFile map (_.toTry.get) getOrElse Configuration()
    m.get("Architectures") foreach { d => c = c.archDir(Paths.get(d)) }
    m.get("Cores")         foreach { d => c = c.coreDir(Paths.get(d)) }
    m.get("Compositions")  foreach { d => c = c.compositionDir(Paths.get(d)) }
    m.get("Kernels")       foreach { d => c = c.kernelDir(Paths.get(d)) }
    m.get("Platforms")     foreach { d => c = c.platformDir(Paths.get(d)) }
    m.get("Slurm")         foreach { d => c = c.slurm(d.toBoolean) }
    m.get("Parallel")      foreach { d => c = c.parallel(d.toBoolean) }
    m.get("LogFile")       foreach { d => c = c.logFile(Some(Paths.get(d))) }
    if (jobs.nonEmpty || m.get("JobsFile").nonEmpty) {
      c.jobs(m.get("JobsFile") map (p => readJobsFile(p)) getOrElse jobs)
    } else {
      c
    }
  }
  /* Configuration @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
