package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  java.nio.file.Paths

private object DesignSpaceExplorationJobParser {
  import CommandLineParser._

  /** Returns a parser for DesignSpaceExplorationJob. */
  def apply(): Parser[Job] = dseJob

  /* @{ DesignSpaceExplorationJob */
  private def dimensions: Parser[DesignSpace.Dimensions] = param("dimensions", false) ~> rep1sep(
    """^(?i)area""".r                 ^^ { _ => (d: DesignSpace.Dimensions) => d.copy(utilization = true) }  |
    """^(?i)freq(?:uency)?""".r       ^^ { _ => (d: DesignSpace.Dimensions) => d.copy(frequency = true) }    |
    """^(?i)alt(?:s|ternatives)?""".r ^^ { _ => (d: DesignSpace.Dimensions) => d.copy(alternatives = true) },
    LIST_SEP
  ) ^^ { ds => (ds fold identity[DesignSpace.Dimensions] _) (_ compose _) (DesignSpace.Dimensions()) }

  private def heuristic: Parser[Heuristics.Heuristic] =
    (param("heuristic") ~> """(?i:throughput)""".r) ^^ { _ => Heuristics.ThroughputHeuristic }

  private def dseArgs: Parser[(String, String)] = (
    (param("debugmode", false) ~> ident)       ^^ { p => ("debugmode", p) }          |
    (param("frequency", false) ~> path)        ^^ { p => ("frequency", p) }          |
    (param("basepath", false) ~> path)         ^^ { p => ("basepath", p) }           |
    (param("batchsize", false) ~> wholeNumber) ^^ { p => ("batchsize", p.toString) } |
    architecturesFilter                                                              |
    platformsFilter
  )

  private def dseJob: Parser[Job] =
    job("dse") ~> CompositionParser() ~ dimensions ~ opt(heuristic) ~ rep(dseArgs) ~ opt(FeatureParser()) ^^ { p =>
      val m = p._1._2.toMap
      if (m.get("batchsize").isEmpty) throw new Exception("missing parameter --batchSize for DSE")
      DesignSpaceExplorationJob(
        initialComposition = p._1._1._1._1,
        initialFrequency   = m.get("frequency") map (_.toDouble) getOrElse 100.0,
        dimensions         = p._1._1._1._2,
        heuristic          = p._1._1._2 getOrElse Heuristics.ThroughputHeuristic,
        batchSize          = m("batchsize").toInt,
        basePath           = m.get("basepath") map (p => Paths.get(p)),
        _architectures     = m.get("architectures") map (_.split(LIST_MK)),
        _platforms         = m.get("platforms") map (_.split(LIST_MK)),
        features           = p._2,
        debugMode          = m.get("debugmode")
      )
  }
  /* DesignSpaceExplorationJob @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
