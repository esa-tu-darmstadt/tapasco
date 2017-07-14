package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.dse.Heuristics.Frequency
import  fastparse.all._
import  java.nio.file._
import  scala.language.implicitConversions

private object BasicParsers {
  def longOption(name: String): Parser[String] = longOption(name, name)
  def longOption(name: String, retVal: String, alternatives: String*) =
    (name +: alternatives) map (n => IgnoreCase("--%s".format(n)).!.map(_ => retVal)) reduce (_|_)

  def longShortOption(shortName: String, longName: String, retVal: Option[String] = None) =
    IgnoreCase("-%s".format(shortName)).! | IgnoreCase("--%s".format(longName)).! map (retVal getOrElse _)

  val argChars = "-"
  val quoteChars = "\"'"
  val seqSepChars = ";,:"
  val whitespaceChars = " \n\t"
  val specialChars = whitespaceChars ++ quoteChars ++ seqSepChars ++ argChars
  val digitChars = '0' to '9'
  val alphaChars = ('a' to 'z') ++ ('A' to 'Z')
  val nonStringChars = whitespaceChars ++ quoteChars ++ seqSepChars

  val ws = NoTrace(CharIn(whitespaceChars).rep.opaque("whitespace"))
  val ws1 = NoTrace(CharIn(whitespaceChars).rep(1).opaque("whitespace"))
  val seqSep = CharIn(seqSepChars)
  val sep = ws ~ seqSep.opaque(s"list separator, one of $seqSepChars") ~ ws
  val quote = CharIn(quoteChars).opaque(s"quote char, one of $quoteChars")

  def string(exceptionChars: String): Parser[String] =
    (CharPred(!(exceptionChars ++ nonStringChars).contains(_)).rep(1).!)
      .opaque(s"string containing none of '$exceptionChars'")

  def string(exceptionStrings: Seq[String]): Parser[String] =
    // compute exception chars as first char in each exception string
    string(exceptionStrings filter (_.nonEmpty) map (_.apply(0)) mkString)
      .filter (s => (exceptionStrings map (!s.contains(_)) fold true) (_ && _))
      .opaque(s"string containing none of $exceptionStrings")

  val string: Parser[String] =
    (CharIn(alphaChars).! ~ CharPred(!nonStringChars.contains(_)).rep.!)
      .opaque("unquoted string")
      .map { case (s, ss) => s ++ ss }

  val quotedString: Parser[String] =
    (quote ~/ CharPred(!quoteChars.contains(_)).rep.! ~ quote)
      .opaque("quoted string")

  val qstring: Parser[String] =
    (string | quotedString)
      .opaque("quoted or unquoted string")

  def seq[A](p: Parser[A]): Parser[Seq[A]] = p.rep(sep=sep.~/) ~ !(sep)

  def seqOne[A](p: Parser[A]): Parser[Seq[A]] = p.rep(1, sep=sep.~/) ~ !(sep)

  val numstr: Parser[String] = CharIn(digitChars).rep(1).!

  val posint: Parser[Int] = numstr.map(_.toInt).opaque("positive integer")

  val signednumstr: Parser[String] =
    ("-".!.? ~ numstr.!) map { case (s, i) => s.getOrElse("") ++ i }

  val signedint: Parser[Int] = signednumstr map (_.toInt) opaque "integer"

  val dblstr: Parser[String] =
    (signednumstr.! ~ (CharIn(",.") ~ numstr).!.?) map { case (n, r) => n ++ r.getOrElse("")  }

  val double: Parser[Double] = dblstr.map(_.toDouble)
      .opaque("floating point number")

  val frequency: Parser[Frequency] = double.opaque("frequency in MHz")

  implicit def toPath(s: String): Path = Paths.get(s)
  def tryToPath(s: String): Option[Path] = scala.util.Try(toPath(s)).toOption

  val path: Parser[Path] =
    (quotedString | CharPred(!whitespaceChars.contains(_)).rep(1).!)
      .filter(p => tryToPath(p).nonEmpty)
      .map(toPath _)
      .opaque("path")
}
