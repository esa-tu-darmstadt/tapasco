package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class DesignSpaceExplorationParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import DesignSpaceExplorationParser._, DesignSpaceExplorationParserSpec._
  implicit val cfg = PropertyCheckConfiguration(minSize = 50000, sizeRange = 1000)

  "All valid DSE jobs" should "be parsed correctly" in
    check(forAllNoShrink(dseGen) { d =>
      Common.checkParsed(P( dse ~ End ).parse(d))
    })
}

private object DesignSpaceExplorationParserSpec {
  import BasicParserSpec._, CommonArgParsersSpec._, GlobalOptionsSpec.pathGen

  val dimensionGen: Gen[String] = Gen.oneOf(
    anyCase("area"),
    anyCase("utilization"),
    anyCase("util"),
    anyCase("freq"),
    anyCase("frequency"),
    anyCase("alts"),
    anyCase("alternatives")
  )

  val dimensionsGen: Gen[String] = for {
    n <- Gen.choose(1, 5)
    s <- join(0 until n map (_ => dimensionGen), sepStringGen)
  } yield s

  val heuristicGen: Gen[String] = join(Seq(
    genLongOption("heuristic"),
    Gen.oneOf(anyCase("throughput"), quoted(anyCase("job throughput")))
  ))

  val batchSizeGen: Gen[String] = join(Seq(
    genLongOption("batchSize"),
    Gen.posNum[Int] map (_.toString)
  ))

  val basePath: Gen[String] = join(Seq(
    genLongOption("basePath"),
    pathGen map (_.toString)
  ))

  val optionGen: Gen[String] = Gen.oneOf(
    heuristicGen,
    batchSizeGen,
    basePath,
    architecturesGen,
    platformsGen
  )

  val optionsGen: Gen[String] = for {
    n <- Gen.choose(0, 10)
    o <- join(0 until n map (_ => optionGen))
  } yield o

  val dseGen: Gen[String] = join(Seq(
    anyCase("explore"),
    compositionGen,
    Gen.option(join(Seq("@", freqGen))) map (_ getOrElse ""),
    "in",
    dimensionsGen,
    optionsGen
  ))
}
