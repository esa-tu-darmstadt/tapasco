package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._
import  java.nio.file.Path

private object DesignSpaceExplorationParser {
  import BasicParsers._
  import CommonArgParsers._
  import FeatureParsers._

  def dse: Parser[DesignSpaceExplorationJob] = (
      IgnoreCase("explore") ~ ws ~/ composition ~/ ws ~
        ("@" ~ ws ~/ freq ~ ws1).? ~ ws ~
        IgnoreCase("in") ~ ws ~/ dimensions ~/ ws ~ options ~ ws
    ) map { case (_, comp, optfreq, dims, optf) => optf(DesignSpaceExplorationJob(
      initialComposition = comp,
      initialFrequency = optfreq getOrElse 100.0,
      dimensions = dims,
      heuristic = Heuristics.ThroughputHeuristic,
      batchSize = Runtime.getRuntime().availableProcessors()
    ))}

  private def optionsMap: Parser[Seq[(String, _)]] =
    (heuristic | batchSize | basePath | architectures | platforms | features | debugMode).rep

  private val jobid = identity[DesignSpaceExplorationJob] _

  private def options: Parser[DesignSpaceExplorationJob => DesignSpaceExplorationJob] =
    optionsMap map (opts => (opts map (applyOption _) fold jobid) (_ andThen _))

  private def heuristic: Parser[(String, String)] =
    longOption("heuristic", "Heuristic") ~ ws ~/ qstring.opaque("name of heuristic") ~ ws

  private def batchSize: Parser[(String, Int)] =
    longOption("batchSize", "BatchSize") ~ ws ~/ posint.opaque("batch size, positive integer > 0") ~ ws

  private def basePath: Parser[(String, Path)] =
    longOption("basePath", "BasePath") ~ ws ~/ path.opaque("base path") ~ ws

  private def applyOption(opt: (String, _)): DesignSpaceExplorationJob => DesignSpaceExplorationJob =
    opt match {
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", as: Seq[String @unchecked]) => _.copy(_platforms = Some(as))
      case ("Heuristic", h: String) => _.copy(heuristic = Heuristics(h))
      case ("BatchSize", i: Int) => _.copy(batchSize = i)
      case ("BasePath", p: Path) => _.copy(basePath = Some(p))
      case ("Features", fs: Seq[Feature @unchecked]) => _.copy(features = Some(fs))
      case ("DebugMode", m: String) => _.copy(debugMode = Some(m))
      case o => throw new Exception(s"parsed illegal option: $o")
    }

  private def set(s: String): DesignSpace.Dimensions => DesignSpace.Dimensions =
    s.toLowerCase match {
      case "area" | "util" | "utilization" => _.copy(utilization = true)
      case "freq" | "frequency" => _.copy(frequency = true)
      case "alt" | "alts" | "alternatives" => _.copy(alternatives = true)
      case _ => throw new Exception(s"unknown design space dimension: '$s'")
    }

  private val dimid = identity[DesignSpace.Dimensions] _

  private def dimension = StringInIgnoreCase(
    "area", "util", "utilization",
    "freq", "frequency",
    "alt", "alts", "alternatives"
  ).!

  private def dimensions: Parser[DesignSpace.Dimensions] =
    seqOne(dimension) map { ss =>
      (((ss map (set _)) fold dimid) (_ andThen _)) (DesignSpace.Dimensions())
    }
}
