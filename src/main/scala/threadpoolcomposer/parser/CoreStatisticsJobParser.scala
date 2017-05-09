package de.tu_darmstadt.cs.esa.threadpoolcomposer.parser
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs._

private object CoreStatisticsJobParser {
  import CommandLineParser._

  /** Returns a CoreStatisticsJob parser. */
  def apply(): Parser[Job] = coreStatsJob

  /* @{ CoreStatisticsJob */
  private def coreStatsArgs: Parser[(String, String)] = (
    (param("prefix", false) ~> ident) ^^ { p => ("prefix", p) } |
    architecturesFilter                                         |
    platformsFilter
  )

  private def coreStatsJob: Parser[Job] = (job("corestats") ~> rep(coreStatsArgs)) ^^ { p =>
    val m = p.toMap
    CoreStatisticsJob(
      m.get("prefix"),
      m.get("architectures") map (_.split(LIST_MK)),
      m.get("platforms") map (_.split(LIST_MK))
    )
  }
  /* CoreStatisticsJob @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
