package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  MultiFileWatcher._, Events._
import  LogTrackingFileWatcher._
import  java.nio.file.Paths

/** A [[MultiFileWatcher]] which tracks a logfile:
 *  subsequent logfiles mentioned in the log (matched via regex) are tracked recursively,
 *  making it easy to follow complex outputs, e.g., from Vivado.
 *  @param logger Optional logger instance to use.
 *  @param pollInterval Optional polling interval for files.
 **/
class LogTrackingFileWatcher(_logger: Option[Logger] = None, pollInterval: Int = POLL_INTERVAL)
    extends MultiFileWatcher(POLL_INTERVAL) {
  private[this] final val logger = _logger getOrElse de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private object listener extends Listener[Event]{
    def update(e: MultiFileWatcher.Event): Unit = e match {
      case LinesAdded(src, ls) => ls map { l =>
        logger.info(l)
        newFileRegex foreach { rx => rx.findAllMatchIn(l) foreach { m =>
          Option(m.group(1)) match {
            case Some(p) if p.trim().nonEmpty =>
              addPath(Paths.get(p))
              logger.trace("adding new file: {}", p)
            case _ => {}
          }
        }}
      }
    }
  }

  addListener(listener)
}

private object LogTrackingFileWatcher {
  val newFileRegex = Seq(
    """(?i)output in (\S*)$""".r.unanchored,
    """(?i)\s*(\S*/synth_1/runme\.log)$""".r.unanchored,
    """(?i)\s*(\S*/impl_1/runme\.log)$""".r.unanchored)
}
