package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class HighLevelSynthesisParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import HighLevelSynthesisParser._, HighLevelSynthesisParserSpec._, Common._
  implicit val cfg = PropertyCheckConfiguration(minSize = 100000)

  "All valid HLS jobs" should "be correctly parsed by hls" in
    check(forAll(hlsGen) { h =>
      checkParsed(P( hls ~ End ).parse(h))
    })
}

private object HighLevelSynthesisParserSpec {
  import BasicParserSpec._, CommonArgParsersSpec._

  val implementationGen: Gen[String] = join(Seq(
    genLongOption("implementation"),
    Gen.oneOf(anyCase("VivadoHLS"), quoted(anyCase("VivadoHLS")))
  ))

  val kernelGen: Gen[String] = qstringGen
  val allGen: Gen[String]    = anyCase("all")

  val optionGen: Gen[String] = Gen.oneOf(
    platformsGen,
    architecturesGen,
    implementationGen
  )

  val optionsGen: Gen[String] = for {
    n <- Gen.choose(0, 10)
    s <- join(0 until n map (_ => optionGen))
  } yield s

  val hlsGen: Gen[String] = join(Seq(
    anyCase("hls"),
    Gen.oneOf(allGen, seqOne(kernelGen, sepStringGen)),
    optionsGen
  ))
}
