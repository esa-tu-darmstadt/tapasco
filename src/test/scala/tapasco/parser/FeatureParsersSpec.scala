package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class FeatureParsersSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import Common._
  import FeatureParsers._, FeatureParsersSpec._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000, sizeRange = 1000)

  "All valid key-value pairs" should "be parsed by featureKeyValue" in
    check(forAllNoShrink(featureKeyValueGen) { f =>
      checkParsed(P( featureKeyValue ~ End ).parse(f) )
    })


  "All valid features" should "be parsed by feature" in
    check(forAllNoShrink(featureGen) { f =>
      checkParsed(P( feature ~ End ).parse(f) )
    })
}

private object FeatureParsersSpec {
  /* {@ Generators and Arbitraries */
  val assignStrings = Seq("->", "=", ":", ":=")
  val featureAssignGen: Gen[String] = Gen.oneOf(assignStrings)

  val featureKeyValueGen: Gen[String] = for {
    key   <- BasicParserSpec.qstringGen retryUntil (s => assignStrings map (!s.contains(_)) reduce (_ && _))
    value <- BasicParserSpec.qstringGen retryUntil (s => assignStrings map (!s.contains(_)) reduce (_ && _))
    ass   <- featureAssignGen
    ws1   <- BasicParserSpec.ws1StringGen
    ws2   <- BasicParserSpec.ws1StringGen
  } yield s"$key$ws1$ass$ws2$value"

  val featureBeginGen: Gen[Char] = Gen.oneOf(FeatureParsers.featureBeginChars)
  val featureEndGen: Gen[Char]   = Gen.oneOf(FeatureParsers.featureEndChars)
  def matching(c: Char): Char    = c match {
    case '[' => ']'
    case '{' => '}'
    case '(' => ')'
  }

  def featureKVs(n: Int): Gen[String] = 
    BasicParserSpec.join(0 until n map { _ => featureKeyValueGen })

  val featureGen: Gen[String] = for {
    begin <- featureBeginGen
    name  <- BasicParserSpec.qstringGen
    n     <- Gen.chooseNum(0, 5)
    kvs   <- featureKVs(n)
    ws1   <- BasicParserSpec.ws1StringGen
    ws2   <- BasicParserSpec.ws1StringGen
    ws3   <- BasicParserSpec.ws1StringGen
    end   =  matching(begin)
  } yield s"$name$ws1$begin$ws2$kvs$ws3$end"

  val featuresGen: Gen[String] = for {
    o  <- BasicParserSpec.genLongOption("features")
    w  <- BasicParserSpec.ws1StringGen
    n  <- Gen.chooseNum(1, 4)
    fs <- BasicParserSpec.join(0 until n map { _ => featureGen }, BasicParserSpec.sepStringGen)
  } yield s"$o$w$fs"
  /* Generators and Arbitraries @} */
}
