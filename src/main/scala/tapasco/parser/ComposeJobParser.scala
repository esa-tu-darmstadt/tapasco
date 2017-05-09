package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._

private object ComposeJobParser {
  import CommandLineParser._

  /** Returns a parser for a ComposeJob. */
  def apply(): Parser[Job] = composeJob

  /* @{ ComposeJob */
  private def designFrequency: Parser[Int] =
    (param("designfrequency", false) ~> wholeNumber) ^^ { p => p.toInt }

  private def compImpl: Parser[String] = (param("implementation", false) ~> ident)

  private def composeArgs: Parser[(String, String)] = (
    (param("debugmode", false) ~> ident) ^^ { ("debugmode", _) } |
    architecturesFilter                                          |
    platformsFilter
  )

  private def composeJob: Parser[Job] =
    (job("compose") ~> CompositionParser() ~
                       designFrequency ~
                       opt(compImpl) ~
                       rep(composeArgs) ~
                       opt(FeatureParser())) ^^ { p =>
      val m = p._1._2.toMap
      ComposeJob(
        p._1._1._1._1,
        p._1._1._1._2,
        p._1._1._2 getOrElse "Vivado",
        m.get("architectures") map (_.split(LIST_MK)),
        m.get("platforms") map (_.split(LIST_MK)),
        p._2,
        m.get("debugmode")
      )
    }
  /* ComposeJob @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
