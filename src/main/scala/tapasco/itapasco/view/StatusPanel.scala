package de.tu_darmstadt.cs.esa.tapasco.itapasco.view
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._

/** Status panel is a UI element showing a single status line.
 *  It shows the number of running tasks and consumed resources.
 */
class StatusPanel extends BorderPanel with Listener[Tasks.Event] {
  import StatusPanel._
  private def mkText(tasks: Tasks): String = Seq(
    "%s".format(tasks.resourceStatus),
    "%d tasks queued".format(tasks.queued.length),
    "%d tasks running".format(tasks.running.length),
    "%d tasks completed   ".format(tasks.complete.length)
  ) mkString ", " replace (",", " |")

  private[this] val _label = new Label("") {
    foreground = STATUS_FG_COLOR
  }

  def update(e: Tasks.Event): Unit = {
    _label.text = mkText(e.source)
    revalidate()
  }

  background = STATUS_BG_COLOR
  border = Swing.CompoundBorder(
    Swing.BeveledBorder(Swing.Lowered),
    Swing.EmptyBorder(STATUS_BORDER_SZ))

  layout(_label) = BorderPanel.Position.East
}

object StatusPanel {
  /** Status bar text color. */
  final val STATUS_FG_COLOR  = java.awt.Color.white
  // scalastyle:off magic.number
  /** Status bar background color. */
  final val STATUS_BG_COLOR  = new java.awt.Color(50, 50, 70)
  // scalastyle:on magic.number
  /** Status bar border width. */
  final val STATUS_BORDER_SZ = 2
}
