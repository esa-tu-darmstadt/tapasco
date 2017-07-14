package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object HighLevelSynthesisParser {
  import BasicParsers._
  import CommonArgParsers._

  def hls: Parser[HighLevelSynthesisJob] =
    IgnoreCase("hls") ~ ws ~/ kernels ~ ws ~/ options map { case (ks, optf) =>
      optf(HighLevelSynthesisJob(_implementation = "VivadoHLS",
                                 _kernels = ks))
    }

  private def kernels: Parser[Option[Seq[String]]] = (
    ((IgnoreCase("all").! ~/ ws) map (_ => None)) |
    ((seqOne(kernel) ~/ ws) map { Some(_) })
  ).opaque("either 'all', or a list of kernel names")

  private val jobid = identity[HighLevelSynthesisJob] _

  private def options: Parser[HighLevelSynthesisJob => HighLevelSynthesisJob] =
    (implementation | architectures | platforms).rep map (opt =>
      (opt map (applyOption _) fold jobid) (_ andThen _))

  private def applyOption(opt: (String, _)): HighLevelSynthesisJob => HighLevelSynthesisJob =
    opt match {
      case ("Implementation", i: String) => _.copy(_implementation = i)
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
