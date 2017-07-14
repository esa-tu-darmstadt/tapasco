package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class JobParsersSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import JobParsers._, JobParsersSpec._, Common._

  "All valid jobs" should "be correctly parsed by job" in
    check(forAllNoShrink(jobGen) { h =>
      checkParsed(P( job ~ End ).parse(h))
    })
  "All sequences of valid jobs" should "be correctly parsed by jobs" in
    check(forAllNoShrink(jobsGen) { h =>
      checkParsed(P( jobs ~ End ).parse(h))
    })
}

private object JobParsersSpec {
  val jobGen: Gen[String] = Gen.oneOf(
    BulkImportParserSpec.bulkImportGen,
    ComposeParserSpec.composeGen,
    CoreStatisticsParserSpec.corestatsGen,
    ImportParserSpec.importGen,
    HighLevelSynthesisParserSpec.hlsGen,
    DesignSpaceExplorationParserSpec.dseGen
  )

  val jobsGen: Gen[String] = for {
    n <- Gen.choose(0, 500)
    s <- BasicParserSpec.join(0 until n map (_ => jobGen))
  } yield s
}
