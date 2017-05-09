package de.tu_darmstadt.cs.esa.threadpoolcomposer.parser
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs._
import  java.nio.file.Paths

private object ImportJobParser {
  import CommandLineParser._

  /** Returns a parser for an ImportJob. */
  def apply(): Parser[Job] = importJob

  /* @{ ImportJob */
  private def importArgs: Parser[(String, String)] = (
    (param("zip",false) ~> path)                        ^^ { p => ("zip", p) }                |
    (param("id", false) ~> """\d+""".r)                 ^^ { p => ("id", p) }                 |
    (param("averageClockCycles", false) ~> """\d+""".r) ^^ { p => ("averageClockCycles", p) } |
    (param("description", false) ~> path)               ^^ { p => ("description", p) }        |
    architecturesFilter |
    platformsFilter
  )

  private def importJob: Parser[Job] = (job("import") ~> rep1(importArgs)) ^^ { p =>
    val m = p.toMap
    ImportJob(
      Paths.get(m("zip")),
      m("id").toInt,
      m.get("description"),
      m.get("averageClockCycles") map (_.toInt),
      m.get("architectures") map (_.split(LIST_MK)),
      m.get("platforms") map (_.split(LIST_MK))
    )
  }
  /* ImportJob @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
