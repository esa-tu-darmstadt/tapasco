package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object JobParsers {
  import BulkImportParser._
  import CoreStatisticsParser._
  import ComposeParser._
  import ImportParser._
  import HighLevelSynthesisParser._
  import DesignSpaceExplorationParser._

  def job: Parser[Job] =
    bulkimport | compose | corestats | importzip | hls | dse

  def jobs: Parser[Seq[Job]] = job.rep
}
