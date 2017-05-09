package de.tu_darmstadt.cs.esa.threadpoolcomposer.parser
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs._

private object HighLevelSynthesisJobParser {
  import CommandLineParser._

  /** Returns a parser for a HighLevelSynthesisJob. */
  def apply(): Parser[Job] = hlsJob

  /* @{ HighLevelSynthesisJob */
  private def hlsArgs: Parser[(String, String)] = (
    (param("implementation") ~ ident) ^^ { p => (p._1, p._2) } |
    architecturesFilter                                        |
    platformsFilter                                            |
    kernelsFilter
  )

  private def hlsJob: Parser[Job] = (job("hls") ~> rep(hlsArgs)) ^^ { p =>
    val m = p.toMap
    HighLevelSynthesisJob(
      m.getOrElse("implementation", "VivadoHLS"),
      m.get("architectures") map (_.split(LIST_MK)),
      m.get("platforms") map (_.split(LIST_MK)),
      m.get("kernels") map (_.split(LIST_MK))
    )
  }
  /* HighLevelSynthesisJob @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
