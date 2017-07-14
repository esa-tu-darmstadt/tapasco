package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Button, Label, Table}
import  scala.swing.event.ButtonClicked
import  javax.swing.AbstractCellEditor
import  javax.swing.JTable
import  javax.swing.table.TableCellEditor

/**
 * CoreTable displays a list of Cores and Kernels, along with their current
 * instantiation count in the configured Composition, availibility of Cores
 * for each Platform and a build button to start HLS (if possible).
 * @param m Model instances to associate with.
 **/
class CoreTable extends Table with Publisher {
  type Event = CoreTable.Event
  import CoreTable._, CoreTable.Events._

  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  val coreTableModel = new CoreTableModel

  private[this] def _buildButtons = coreTableModel.getData() map { cl => if (cl.buildable) {
      mkBuildButton(cl.d.asInstanceOf[Kernel])
    } else {
      mkBuildLabel(cl)
    }}
  private[this] def _buildButtonEditors = _buildButtons map {
    case b: Button => Some(mkBuildButtonEditor(b))
    case _ => None
  }

  // set TableModel to CoreTableModel
  model = coreTableModel
  listenTo(this) // listen to model updates to recompute column widths
  reactions += {
    case scala.swing.event.TableStructureChanged(_) => scala.swing.Swing.onEDT { computeWidths() }
    case scala.swing.event.TableUpdated(_, _, _)    => scala.swing.Swing.onEDT { computeWidths() }
  }
  selection.elementMode = scala.swing.Table.ElementMode.Row     // select full rows
  selection.intervalMode = Table.IntervalMode.Single            // select single row
  peer.getTableHeader().setReorderingAllowed(false)             // fixed ordering of columns
  computeWidths()                                               // compute widths for initial values

  /** Returns the description at given row. */
  def apply(row: Int): Description = coreTableModel.getData()(row).d

  /** Returns the currently selected description, if any. */
  def description(): Option[Description] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(coreTableModel.getData()(selection.rows.min).d)
  }

  override def rendererComponent(isSelected: Boolean, hasFocus: Boolean, row: Int, col: Int): scala.swing.Component =
    if (col == model.getColumnCount() - 1) {
      _buildButtons(row)
    } else {
      super.rendererComponent(isSelected, hasFocus, row, col)
    }

  override def editor(row: Int, col: Int): TableCellEditor =
    if (col == model.getColumnCount() - 1 && model.asInstanceOf[CoreTableModel].getData()(row).buildable) {
      _buildButtonEditors(row).get
    } else {
      super.editor(row, col)
    }

  private class BuildButton(k: Kernel)(implicit parent: CoreTable = this) extends Button("Build") {
    listenTo(this)
    reactions += { case ButtonClicked(_) =>
      this.enabled = false
      parent.publish(HighLevelSynthesisRequested(k))
    }
  }

  private def mkBuildButton(k: Kernel): Button = new BuildButton(k)

  private def mkBuildButtonEditor(b: Button) = new AbstractCellEditor with TableCellEditor {
    listenTo(b)
    reactions += { case ButtonClicked(`b`) => fireEditingStopped() }

    def getCellEditorValue: AnyRef = None
    def getTableCellEditorComponent(t: JTable, value: AnyRef, isSelected: Boolean, row: Int, col: Int): java.awt.Component = b.peer
  }

  private def mkBuildLabel(cl: CoreTableModel.CoreTableRow): Label = if (cl.coreAvailable reduce (_&&_)) {
    new Label("all ready!")
  } else {
    if (coreTableModel.isBuilding(cl.d.name)) {
      new Label("HLS still running...")
    } else {
      new Label("no kernel description found") { foreground = java.awt.Color.red }
    }
  }

  private def computeWidths(): Unit = {
    val cols = 0 until peer.getColumnModel().getColumnCount() map { i => (i, peer.getColumnModel().getColumn(i)) }
    cols foreach { case (cidx, col) =>
      // set min/max widths for all columns except name (first)
      if (cidx > 0) {
        col.setMinWidth(if (cidx == 1) COL_MIN_WIDTH_COUNT else COL_MIN_WIDTH_TARGET)
        col.setMaxWidth(COL_MAX_WIDTH)
      }
      val maxwidth  = col.getMaxWidth()
      val bestwidth = ((for {
        ridx <- 0 until model.getRowCount()//rowCount
        if cidx < model.getColumnCount()
        c = peer.prepareRenderer(peer.getCellRenderer(ridx, cidx), ridx, cidx)
      } yield c.getPreferredSize().width + peer.getIntercellSpacing().width) :+ 0).max
      col.setPreferredWidth(if (bestwidth > maxwidth) maxwidth else bestwidth)
    }
  }
}

/** Companion object: contains width constants. */
object CoreTable {
  protected final val COL_MIN_WIDTH_TARGET = 100
  protected final val COL_MIN_WIDTH_COUNT  = 30
  protected final val COL_MAX_WIDTH        = 250

  sealed trait Event
  object Events {
    final case class HighLevelSynthesisRequested(k: Kernel) extends Event
  }
}
