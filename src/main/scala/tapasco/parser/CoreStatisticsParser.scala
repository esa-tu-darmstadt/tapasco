package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object CoreStatisticsParser {
  import BasicParsers._
  import CommonArgParsers._

  def corestats: Parser[CoreStatisticsJob] =
    IgnoreCase("corestats") ~/ ws1 ~ options ~ ws map (_.apply(CoreStatisticsJob()))

  private val jobid = identity[CoreStatisticsJob] _

  private def prefix: Parser[(String, String)] =
    longOption("prefix", "Prefix") ~ ws ~/ qstring.opaque("prefix string") ~ ws

  private def options: Parser[CoreStatisticsJob => CoreStatisticsJob] =
    (prefix | architectures | platforms).rep map (opts =>
      (opts map (applyOption _) fold jobid) (_ andThen _))

  private def applyOption(opt: (String, _)): CoreStatisticsJob => CoreStatisticsJob =
    opt match {
      case ("Prefix", prefix: String) => _.copy(prefix = Some(prefix))
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
