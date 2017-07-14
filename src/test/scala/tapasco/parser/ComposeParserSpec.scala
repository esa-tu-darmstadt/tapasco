package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class ComposeParserSpec extends FlatSpec with Matchers with Checkers {
  import ComposeParser._, ComposeParserSpec._
  import Prop._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000, sizeRange = 0)

  "All valid compose job specs" should "be parsed correctly by compose" in
    check(forAllNoShrink(composeGen) { cj =>
      Common.checkParsed( P( compose ~ End ).parse(cj) )
    })
}

private object ComposeParserSpec {
  /* @{ Generators and Arbitraries */
  val optionGen: Gen[String] = Gen.oneOf(
    CommonArgParsersSpec.implementationGen,
    CommonArgParsersSpec.architecturesGen,
    CommonArgParsersSpec.platformsGen,
    FeatureParsersSpec.featuresGen,
    CommonArgParsersSpec.debugModeGen
  )
  val optionsGen: Gen[String] = for {
    n <- Gen.choose(1, 20)
    p <- BasicParserSpec.join(0 until n map (_ => optionGen))
  } yield p.mkString

  val composeGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("compose"),
    CommonArgParsersSpec.compositionGen,
    "@",
    CommonArgParsersSpec.freqGen,
    optionsGen
  ))
  /* Generators and Arbitraries @} */
}
