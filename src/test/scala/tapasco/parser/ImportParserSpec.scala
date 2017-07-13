package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class ImportParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import ImportParser._, ImportParserSpec._, Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 10000)

  "All valid Import jobs" should "be correctly parsed by importzip" in
    check(forAllNoShrink(importGen) { i =>
      checkParsed(P( importzip ~ End ).parse(i))
    })
}

private object ImportParserSpec {
  import BasicParserSpec._, CommonArgParsersSpec._, GlobalOptionsSpec.pathGen

  val descriptionGen: Gen[String] = join(Seq(
    genLongOption("description"),
    qstringGen
  ))

  val avgClockCyclesGen: Gen[String] = join(Seq(
    genLongOption("averageClockCycles"),
    Gen.posNum[Int] map (_.toString)
  ))

  val optionGen: Gen[String] = Gen.oneOf(
    descriptionGen,
    avgClockCyclesGen,
    architecturesGen,
    platformsGen
  )

  val optionsGen: Gen[String] = for {
    n <- Gen.choose(0, 10)
    s <- join(0 until n map (_ => optionGen))
  } yield s

  val importGen: Gen[String] = join(Seq(
    anyCase("import"),
    pathGen map (_.toString),
    "as",
    Gen.posNum[Int] map (_.toString),
    optionsGen
  ))
}
