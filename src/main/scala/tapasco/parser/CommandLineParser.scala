package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.{Entity, Entities}
import  scala.util.parsing.combinator._
import  scala.util.matching.Regex

object CommandLineParser extends JavaTokenParsers {
  private[parser] implicit final val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /**
   * Parse the given command line argument string into a configuration.
   * @param text Command line arguments as single string.
   * @return Either [[base.Configuration]] or an exception.
   **/
  def apply(text: String): Either[Exception, Configuration] = try {
    parseAll(OnceParser(ConfigurationParser()), text) match {
      case Success(r, _) => Right(r)
      case NoSuccess(msg, _) => Left(new Exception(msg))
    }
  } catch { case e: Exception => Left(e) }

  /* @{ Helper parsers */
  private[parser] final val LIST_SEP: Regex = """[,:]""".r

  private[parser] final val LIST_MK = " "

  private[parser] def param(p: String, useShort: Boolean = true): Regex = if (useShort) {
    """^(?i)(?:-%s)|(?:(?:--)?%s)""".format(p.toLowerCase.slice(0,1), p.toLowerCase).r
  } else {
    """^(?i)(?:(?:--)?%s)""".format(p.toLowerCase).r
  }

  private[parser] def path: Parser[String] = stringLiteral ^^ { _.stripPrefix("\"").stripSuffix("\"") }  | """\S+""".r

  private[parser] def job(name: String): Regex = """^(?i)%s""".format(name).r

  private[parser] def boolLiteral: Parser[Boolean] =
    """^(?i)(?:y(?:es)?)|(?:t(?:rue)?)""".r ^^ { p => true } |
    """^(?i)(?:n(?:o)?)|(?:f(?:alse)?)""".r ^^ { p => false }

  private[parser] def slurm: Parser[(String, Boolean)] = param("slurm", false) ~ opt(boolLiteral) ^^ {
    p => ("Slurm", p._2 getOrElse true)
  }

  private[parser] def parallel: Parser[(String, Boolean)] = param("parallel", false) ~ opt(boolLiteral) ^^ {
    p => ("Parallel", p._2 getOrElse true)
  }

  private[parser] def configFile: Parser[String] = param("configfile", false) ~> path

  private[parser] def jobsFile: Parser[String] = param("jobsfile", false) ~> path

  private[parser] def logFile: Parser[String] = param("logfile", false) ~> path

  private[parser] def entities: Parser[Entity] = (
    param("core(?:s)?")               ^^ { _ => Entities.Cores } |
    param("arch(?:itecture(?:s)?)?")  ^^ { _ => Entities.Architectures } |
    param("platform(?:s)?")           ^^ { _ => Entities.Platforms } |
    param("kernel(?:s)?")             ^^ { _ => Entities.Kernels } |
    param("composition(?:s)?", false) ^^ { _ => Entities.Compositions }
  )

  private[parser] def entityDirs: Parser[Entity] = (
    param("core(?:s)?Dir", false)              ^^ { _ => Entities.Cores } |
    param("arch(?:itecture(?:s)?)?Dir", false) ^^ { _ => Entities.Architectures } |
    param("platform(?:s)?Dir", false)          ^^ { _ => Entities.Platforms } |
    param("kernel(?:s)?Dir", false)            ^^ { _ => Entities.Kernels } |
    param("composition(?:s)?Dir", false)       ^^ { _ => Entities.Compositions }
  )

  private[parser] def entityFilter: Parser[(Entity, List[String])] =
    entities ~ rep1sep(ident, LIST_SEP) ^^ { p =>  (p._1, p._2) }

  private[parser] def entityDir: Parser[(Entity, String)] =
    entityDirs ~ path ^^ { p => (p._1, p._2) }

  private[parser] def architecturesFilter: Parser[(String, String)] =
    param("arch(?:itecture(?:s)?)?") ~> rep1sep(ident, LIST_SEP) ^^ { p => ("architectures", p mkString LIST_MK) }

  private[parser] def platformsFilter: Parser[(String, String)] =
    param("platform(?:s)?") ~> rep1sep(ident, LIST_SEP) ^^ { p => ("platforms", p mkString LIST_MK) }

  private[parser] def kernelsFilter: Parser[(String, String)] =
    param("kernel(?:s)?") ~> rep1sep(ident, LIST_SEP) ^^ { p => ("kernels", p mkString LIST_MK) }
  /* Helper parsers @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
