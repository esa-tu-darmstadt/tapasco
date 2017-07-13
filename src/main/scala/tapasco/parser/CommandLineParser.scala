package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  scala.util.Properties.{lineSeparator => NL}
import  fastparse.all._

object CommandLineParser {
  import BasicParsers._
  import GlobalOptions._
  import JobParsers._

  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private[parser] def args: Parser[Configuration] =
    globalOptions ~ ws ~/ jobs ~ ws ~ End map { case (c, js) => c.jobs(c.jobs ++ js) }

  def apply(arguments: String): Either[ParserException, Configuration] =
    check(args.parse(arguments))

  case class ParserException(expected: String, index: Int, input: String, marker: String) extends Throwable {
    override def toString(): String = Seq(
      "expected %s at %d".format(expected, index),
      "",
      "\t" + input,
      "\t" + marker
    ) mkString NL
  }

  object ParserException {
    private final val SLICE_WINDOW = (-100, 40)

    def apply(f: Parsed.Failure): ParserException =
      ParserException(f.lastParser.toString,
                      f.index,
                      f.extra.input.slice(f.index + SLICE_WINDOW._1, f.index + SLICE_WINDOW._2)
                                   .replace ("\t", " ")
                                   .replace ("\n", " "),
                      ("~" * f.index + "^").slice(f.index + SLICE_WINDOW._1,
                                                  f.index + SLICE_WINDOW._2))
  }

  def check[A](x: Parsed[A]) = x match {
    case f: Parsed.Failure      => Left(ParserException(f))
    case Parsed.Success(cfg, _) => Right(cfg)
  }
}
