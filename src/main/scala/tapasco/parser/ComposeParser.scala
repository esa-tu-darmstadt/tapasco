package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object ComposeParser {
  import BasicParsers._
  import CommonArgParsers._
  import FeatureParsers._

  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def compose: Parser[ComposeJob] =
    IgnoreCase("compose") ~ ws ~/ composition ~/ "@" ~ ws ~ freq ~/
      ws ~ options ~ ws map { case (_, c, f, optf) => optf(ComposeJob(
        composition = c,
        designFrequency = f,
        _implementation = "Vivado"
      ))}

  private val jobid = identity[ComposeJob] _

  private def options: Parser[ComposeJob => ComposeJob] =
    (implementation | architectures | platforms | features | debugMode).rep
      .map (opts => (opts map (applyOption _) fold jobid) (_ andThen _))

  private def applyOption(opt: (String, _)): ComposeJob => ComposeJob =
    opt match {
      case ("Implementation", i: String) => _.copy(_implementation = i)
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
      case ("Features", fs: Seq[Feature @unchecked]) => _.copy(features = Some(fs))
      case ("Features", fs: Map[_, _]) => { job =>
        logger.warn("new features not implemented yet!")
        job
      }
      case ("DebugMode", m: String) => _.copy(debugMode = Some(m))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
