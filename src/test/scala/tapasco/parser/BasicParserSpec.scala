package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class BasicParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import BasicParserSpec._
  implicit val cfg = PropertyCheckConfiguration(minSize = 50000, sizeRange = 1000)

  "Arbitrary whitespace" should "be matched by ws completely" in
    check(forAll(wsStringGen) { ws =>
      P( BasicParsers.ws ~ End ).parse(ws).isInstanceOf[Parsed.Success[_]]
    })

  "Zero whitespace" should "not be matches by ws" in
    check(P( BasicParsers.ws1 ).parse("").isInstanceOf[Parsed.Failure])

  "Valid strings" should "be matched by string" in
    check(forAllNoShrink(stringGen) { s =>
      P( BasicParsers.string ~ End ).parse(s).isInstanceOf[Parsed.Success[_]]
    })

  "The empty string" should "not be matched by string" in
    check(P( BasicParsers.string ~ End ).parse("").isInstanceOf[Parsed.Failure])

  "Quoted strings" should "not be matched by string" in
    check(forAll(quotedStringGen) { s =>
      P( BasicParsers.string ~ End ).parse(s).isInstanceOf[Parsed.Failure]
    })

  "Valid strings" should "be matched by qstring" in
    check(forAll(stringGen) { s =>
      P( BasicParsers.qstring ~ End ).parse(s).isInstanceOf[Parsed.Success[_]]
    })

  "Valid quoted strings" should "be matched by qstring" in
    check(forAll(qstringGen) { s =>
      P( BasicParsers.qstring ~ End ).parse(s).isInstanceOf[Parsed.Success[_]]
    })

  "All Sequences of char-separated valid quoted strings" should "be matched by seq(qstring)" in
    check(forAll(seq(qstringGen, sepStringGen)) { s =>
      P( BasicParsers.seq(BasicParsers.qstring) ~ End ).parse(s).isInstanceOf[Parsed.Success[_]]
    })

  "Non-empty sequences of char-separated valid quoted strings" should "be matched by seqOne(qstring)" in
    check(forAllNoShrink(seqOne(qstringGen, sepStringGen)) { s =>
      P( BasicParsers.seq(BasicParsers.qstring) ~ End ).parse(s).isInstanceOf[Parsed.Success[_]]
    })

  "All positive integers" should "be matched by posint" in
    check(forAll(Gen.posNum[Int]) { n =>
      P( BasicParsers.posint ~ End ).parse(n.toString).isInstanceOf[Parsed.Success[_]]
    })

  "All integers" should "be matched by signedint" in
    check(forAll { n: Int =>
      P( BasicParsers.signedint ~ End ).parse(n.toString).isInstanceOf[Parsed.Success[_]]
    })

  "Most valid doubles" should "be matched by double" in
    check(forAll { (d: Double) =>
      P( BasicParsers.double ~ End ).parse(f"$d%.16f").isInstanceOf[Parsed.Success[_]]
    })
}

private object BasicParserSpec {
  /* @{ Generators and Arbitraries */
  import scala.collection.JavaConverters._
  def anyCaseChar(c: Char): Gen[Char] = Gen.oneOf(c.toUpper, c.toLower)
  def anyCase(s: String): Gen[String] = for {
    ac <- Gen.sequence(s map (anyCaseChar _))
  } yield (ac.stream().iterator().asScala.toSeq map (_.toString) fold "")(_ ++ _)

  def genLongOption(name: String): Gen[String] = for {
    s <- anyCase(name)
  } yield "--%s".format(s)

  def genShortOption(short: String): Gen[String] = for {
    s <- anyCase(short)
  } yield "-%s".format(s)

  def genLongShortOption(name: String, short: String): Gen[String] = Gen.oneOf(
    genLongOption(name),
    genShortOption(short)
  )
  val wsCharGen: Gen[Char] = Gen.oneOf(" \t")//Gen.oneOf(BasicParsers.whitespaceChars)
  val wsStringGen: Gen[String] = for {
    n <- Gen.choose(0, 3)
    s <- Gen.buildableOfN[String, Char](n, wsCharGen)
  } yield s
  val ws1StringGen: Gen[String] = for {
    n <- Gen.choose(1, 3)
    s <- Gen.buildableOfN[String, Char](n, wsCharGen)
  } yield s

  val stringCharGen: Gen[Char] =
    Gen.alphaNumChar
    //Arbitrary.arbitrary[Char].retryUntil(!BasicParsers.nonStringChars.contains(_))

  val stringGen: Gen[String] = for {
    n  <- Gen.choose(1, 30)
    c  <- Gen.oneOf(BasicParsers.alphaChars)
    cs <- Gen.buildableOfN[String, Char](n, stringCharGen)
  } yield c +: cs

  val quoteGen: Gen[Char] = Gen.oneOf(BasicParsers.quoteChars)
  val nonQuoteGen: Gen[Char] =
    Gen.alphaNumChar
    //Arbitrary.arbitrary[Char].retryUntil(!BasicParsers.quoteChars.contains(_))

  def quoted(g: Gen[String]): Gen[String] = for {
    q <- quoteGen
    s <- g
  } yield s"$q$s$q"

  val quotedStringGen: Gen[String] = for {
    n <- Gen.choose(1, 30)
    q <- quoteGen
    s <- Gen.buildableOfN[String, Char](n, nonQuoteGen)
  } yield s"$q$s$q"

  val qstringGen: Gen[String] = Gen.oneOf(stringGen, quotedStringGen)

  val sepCharGen: Gen[Char] = Gen.oneOf(BasicParsers.seqSepChars)

  val sepStringGen: Gen[String] = for {
    ws1 <- wsStringGen
    ws2 <- wsStringGen
    sep <- sepCharGen
  } yield s"$ws1$sep$ws2"

  def interleave[A](as: Seq[A], bs: Seq[A]): Seq[A] = (as, bs) match {
    case (Seq(), bs) => bs
    case (as, Seq()) => as
    case (as, bs)    =>  as.head +: bs.head +: interleave(as.tail, bs.tail)
  }

  def interleave[A](as: Seq[A], sep: A): Seq[A] =
    interleave(as, 0 until as.length - 1 map (_ => sep))

  def join(gens: Seq[Gen[String]], joinGen: Gen[String] = ws1StringGen): Gen[String] = for {
    xs <- Gen.sequence(interleave(gens, joinGen))
  } yield (xs.stream().iterator().asScala.map(_.toString) fold "")(_ ++ _)

  def seq(gen: Gen[String], sep: Gen[String]): Gen[String] = for {
    n <- Gen.choose(0, 20)
    g <- join(0 until n map (_ => gen), sep)
  } yield g

  def seqOne(gen: Gen[String], sep: Gen[String]): Gen[String] = for {
    n <- Gen.choose(1, 20)
    g <- join(0 until n map (_ => gen), sep)
  } yield g
  /* Generators and Arbitraries @} */
}
