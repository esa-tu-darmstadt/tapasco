package de.tu_darmstadt.cs.esa.tapasco.itapasco.executables
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  scala.swing.{Frame, MainFrame, SimpleSwingApplication}
import  java.nio.file._

/** Reads any of the supported report files and displays a table with the data.
 *  Attempts to parse the file using all known [[reports.Report]] instances and
 *  shows a [[common.ReportPanel]] for it on success.
 *  Primarily a debugging tool; can be helpful when adding new data/functionality
 *  to the detail panels in graph view.
 *
 *  @note First argument should be the file name.
 */
object ReportViewer extends SimpleSwingApplication {
  private[this] final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private val reportPanel = new ReportPanel
  private val mf = new MainFrame {
    contents = reportPanel
  }

  def top: Frame = mf

  /** Attempts to parse a [[reports.Report]] from the given file.
   *  @param filename Path to the file.
   *  @return Some [[reports.Report]] on success, None otherwise.
   */
  def loadReport(filename: String): Option[Report] = {
    val fn = Paths.get(filename)
    lazy val rs: Stream[Option[Report]] = Stream.empty :+ CoSimReport(fn) :+ PowerReport(fn) :+ SynthesisReport(fn) :+
      TimingReport(fn) :+ UtilizationReport(fn)
    rs collectFirst { case Some(r) => r }
  }

  override def startup(args: Array[String]) {
    super.startup(args)
    if (args.length > 0) {
      val or = loadReport(args(0))
      or foreach { r => reportPanel.report = r }
      if (or.isEmpty) {
        logger.error("could not load report file: {}", args(0))
        quit()
      }
    }
  }
}
