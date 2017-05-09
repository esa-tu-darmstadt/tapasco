package de.tu_darmstadt.cs.esa.tapasco.activity.hls
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  scala.io.Source
import  java.nio.file._

/** HighLevelSynthesizerLog is the abstract model for a HLS log file.
  * It uses simple pattern matching to identify errors and warnings
  * in text-based log file of a [[HighLevelSynthesizer]].
  *
  * @param file Path to log file.
  **/
final case class HighLevelSynthesizerLog(file: Path) {
  import HighLevelSynthesizerLog._
  private[this] final implicit val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] final lazy val errMsg = "could not read HLS logfile %s: ".format(file.toString)

  /** All lines with errors in the log. */
  lazy val errors: Seq[String] = catchDefault(Seq[String](), Seq(classOf[java.io.IOException]), errMsg) {
    Source.fromFile(file.toString).getLines.filter(l =>  RE_ERROR.findFirstIn(l).nonEmpty).toSeq
  }

  /** All lines with warnings in the log. */
  lazy val warnings: Seq[String] = catchDefault(Seq[String](), Seq(classOf[java.io.IOException]), errMsg) {
    Source.fromFile(file.toString).getLines.filter(l =>  RE_WARN.findFirstIn(l).nonEmpty).toSeq
  }
}

/** Companion object for HighLevelSynthesizerLog.
  * Contains the regular expressions for matching.
  **/
private object HighLevelSynthesizerLog {
  private final val RE_ERROR = """(?i)error""".r.unanchored
  private final val RE_WARN  = """(?i)warn""".r.unanchored
}
