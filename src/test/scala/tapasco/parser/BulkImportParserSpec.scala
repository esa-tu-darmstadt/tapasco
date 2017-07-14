package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._

class BulkImportParserSpec extends FlatSpec with Matchers with Checkers {
  import BulkImportParser._, BulkImportParserSpec._
  import Common._
  import Prop._

  "All valid job specs" should "be parsed correctly by bulkimport" in
    check(forAllNoShrink(bulkImportGen) { bij =>
      checkParsed( P( bulkimport ~ End ).parse(bij) )
    })
}

private object BulkImportParserSpec {
  /* @{ Generators and Arbitraries */
  val bulkImportGen: Gen[String] = BasicParserSpec.join(Seq(
    BasicParserSpec.anyCase("bulkimport"),
    for { p <- GlobalOptionsSpec.pathGen } yield p.toString
  ))
  /* Generators and Arbitraries @} */
}
