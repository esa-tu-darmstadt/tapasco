package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  java.nio.file.Paths

private object BulkImportJobParser {
  import CommandLineParser._

  /** Returns a parser for a BulkImportJob. */
  def apply(): Parser[Job] =
    (job("bulkimport") ~> param("csv", false) ~> path) ^^ { p => BulkImportJob(Paths.get(p)) }
}
