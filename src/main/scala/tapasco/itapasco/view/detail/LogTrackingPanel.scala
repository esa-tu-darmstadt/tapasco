package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing.{BorderPanel, ScrollPane, TextArea}
import  scala.swing.BorderPanel.Position._
import  MultiFileWatcher.Events._
import  java.awt.Color

/** LogTrackingPanel shows a text field with the contents of one or more logfiles,
 *  updated live using an instance of [[filemgmt.MultiFileWatcher]].
 */
class LogTrackingPanel(val task: Task with LogTracking) extends BorderPanel with Listener[MultiFileWatcher.Event] {
  import java.nio.file.Paths
  import scala.util.Properties.{lineSeparator => NL}
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private[this] val log = new TextArea {
    lineWrap = true
    foreground = LogTrackingPanel.LOG_FG_COLOR
    background = LogTrackingPanel.LOG_BG_COLOR
    editable = false
  }
  private[this] val mfw = new MultiFileWatcher
  private[this] val newFileRegex = Seq(
    """(?i)output in (\S*)$""".r.unanchored,
    """(?i)\s*(\S*/synth_1/runme\.log)$""".r.unanchored,
    """(?i)\s*(\S*/impl_1/runme\.log)$""".r.unanchored)

  def update(e: MultiFileWatcher.Event): Unit = e match {
    case LinesAdded(src, ls) => ls map { l =>
      log.append(l + NL)
      log.caret.position = log.text.length

      newFileRegex foreach { rx => rx.findAllMatchIn(l) foreach { m =>
        Option(m.group(1)) match {
          case Some(p) if p.trim().nonEmpty =>
            mfw += Paths.get(p)
            logger.trace("adding new file: {}", p)
          case _ => {}
        }
      }}
    }
  }

  def start(): Unit = if (task.isRunning || task.isCompleted) {
    mfw ++= task.logFiles map (f => Paths.get(f))
  }

  def stop(): Unit = {
    logger.trace("stopping")
    mfw.closeAll
  }

  mfw += this

  layout(new ScrollPane(log)) = Center

  listenTo(this)
  reactions += {
    case scala.swing.event.UIElementShown(_)  => start()
    case scala.swing.event.UIElementHidden(_) => stop()
  }
  start()
}

private object LogTrackingPanel {
  // scalastyle:off magic.number
  final val LOG_BG_COLOR = new Color(50, 50, 70)
  // scalastyle:on magic.number
  final val LOG_FG_COLOR = Color.white
}
