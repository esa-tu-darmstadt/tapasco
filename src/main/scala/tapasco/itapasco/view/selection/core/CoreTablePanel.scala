package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table._
import  de.tu_darmstadt.cs.esa.tapasco.base.{Description, Kernel}
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.ScrollPane
import  scala.swing.event.TableRowsSelected

/** CoreTablePanel displays a CoreTable and listens to its selection object to
 *  update the currently selected Core/Kernel in the model detail.
 **/
class CoreTablePanel extends ScrollPane with Publisher {
  type Event = CoreTablePanel.Event
  import CoreTablePanel.Events._

  private[this] val _mainTable = new CoreTable
  private[this] val PREFERRED_HEIGHT = 100

  viewportView = _mainTable
  listenTo(_mainTable.selection)
  preferredSize = new java.awt.Dimension(0, PREFERRED_HEIGHT)

  reactions += {
    case TableRowsSelected(_, rng, false) => publish(CoreSelected(_mainTable.description()))
  }

  _mainTable += new Listener[CoreTable.Event] {
    def update(e: CoreTable.Event): Unit = e match {
      case CoreTable.Events.HighLevelSynthesisRequested(k) =>
        publish(HighLevelSynthesisRequested(k))
      case _ => {}
    }
  }
}

object CoreTablePanel {
  sealed trait Event
  object Events {
    /** Raised when user selects an element from the table. */
    final case class CoreSelected(od: Option[Description]) extends Event
    /** Raised when user clicks on of the HLS buttons in the table. */
    final case class HighLevelSynthesisRequested(k: Kernel) extends Event
  }
}
