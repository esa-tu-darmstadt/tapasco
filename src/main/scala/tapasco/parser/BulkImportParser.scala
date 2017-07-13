package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

object BulkImportParser {
  import BasicParsers._

  def bulkimport: Parser[BulkImportJob] =
    (IgnoreCase("bulkImport") ~ ws ~/ path.opaque("path to .csv file") ~ ws)
      .map (csv => BulkImportJob(csv))
}
