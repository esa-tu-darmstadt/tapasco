package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.table
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base.Platform
import  scala.swing._

protected[itpc] final class PlatformsTable extends Table {
  private[this] val _ptm = new PlatformsTableModel
  private[this] final val COLWIDTH_TIMESTAMP = 128

  model = _ptm
  selection.elementMode = Table.ElementMode.Row
  selection.intervalMode = Table.IntervalMode.Single
  peer.getTableHeader().setReorderingAllowed(false)
  peer.setColumnSelectionAllowed(false)
  peer.getColumnModel().getColumn(1).setMaxWidth(COLWIDTH_TIMESTAMP)

  def platform: Option[Platform] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(_ptm(selection.rows.min))
  }
}
