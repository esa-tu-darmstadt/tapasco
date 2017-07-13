package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class CoreStatisticsParserSpec extends FlatSpec with Matchers with Checkers {
  import CoreStatisticsParser._, CoreStatisticsParserSpec._
  import Prop._
  import Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000)

  "All valid CoreStat jobs" should "be parsed correctly" in
    check(forAllNoShrink(corestatsGen) { j =>
      checkParsed(P( corestats ~ End ).parse(j))
    })
}

private object CoreStatisticsParserSpec {
  val prefixGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.genLongOption("prefix"),
    BasicParserSpec.qstringGen
  ))

  val optionGen: Gen[String] = Gen.oneOf(
    prefixGen,
    CommonArgParsersSpec.platformsGen,
    CommonArgParsersSpec.architecturesGen
  )

  val optionsGen: Gen[String] = Gen.choose(0, 20) flatMap { n =>
    BasicParserSpec.join(0 until n map (_ => optionGen))
  }

  val corestatsGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("corestats"),
    optionsGen
  ))
}
