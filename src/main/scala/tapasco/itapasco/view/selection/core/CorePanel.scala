package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Button, BorderPanel, GridBagPanel, Swing}
import  scala.swing.event.ButtonClicked
import  scala.swing.BorderPanel.Position._

/** CorePanel shows the cores table and presents UI elements for interaction with
 *  the [[base.Composition]].
 *  It shows a [[CoreTablePanel]] with a [[CompositionSummariesPanel]] and an
 *  import button to import existing IP-XACT .zip files. It publishes
 *  [[CorePanel.Event]] instances in response to user interactions.
 */
class CorePanel extends GridBagPanel with Publisher {
  type Event = CorePanel.Event
  import CorePanel.Events._

  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _importBt = new Button("Import")
  private[this] val _ctbl = new CoreTablePanel
  private[this] val _ctblConstraints = new Constraints {
    gridx = 0
    gridy = 0
    weightx = 1.0
    weighty = 0.75
    fill = GridBagPanel.Fill.Both
  }
  private[this] val _infoPanelConstraints = new Constraints {
    gridx = 0
    gridy = 1
    weightx = 1.0
    weighty = 0.25
    fill = GridBagPanel.Fill.Both
  }

  update()

  listenTo(_importBt)

  reactions += {
    case ButtonClicked(`_importBt`) => publish(ImportRequest)
  }

  def update(): Unit = Swing.onEDT {
    layout.clear()
    layout(_ctbl) = _ctblConstraints
    layout(new BorderPanel {
      layout(new CompositionSummariesPanel) = Center
      layout(new BorderPanel { layout(_importBt) = East }) = East
      border = Swing.EmptyBorder(CorePanel.BORDER_SZ)
    }) = _infoPanelConstraints
  }

  _ctbl += new Listener[CoreTablePanel.Event] {
    def update(e: CoreTablePanel.Event): Unit = e match {
      case CoreTablePanel.Events.CoreSelected(od) => publish(CoreSelected(od))
      case CoreTablePanel.Events.HighLevelSynthesisRequested(k) =>
        publish(HighLevelSynthesisRequest(k))
    }
  }
}

object CorePanel {
  private final val BORDER_SZ = 5

  sealed trait Event
  object Events {
    /** Raised when user selected a kernel/core in the table. */
    final case class CoreSelected(od: Option[Description]) extends Event
    /** Raised when user clicked the import buttons. */
    final case object ImportRequest extends Event
    /** Used when user clicked one of the HLS buttons in the table. */
    final case class HighLevelSynthesisRequest(k: Kernel) extends Event
  }
}
