package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class ParserSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import CommandLineParser._, ParserSpec._, Common._

  "All valid command line argument strings" should "be correctly parsed" in
    check(forAllNoShrink(argsGen) { a =>
      checkParsed(P( args ~ End ).parse(a))
    })
}

private object ParserSpec {
  val argsGen: Gen[String] = BasicParserSpec.join(Seq(
    GlobalOptionsSpec.fullStringGen,
    JobParsersSpec.jobsGen
  ))
}
