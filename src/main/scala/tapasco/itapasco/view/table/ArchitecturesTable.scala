package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.base.Architecture
import  scala.swing._

protected[itapasco] final class ArchitecturesTable extends Table {
  private[this] val _atm = new ArchitecturesTableModel
  private[this] final val COLWIDTH_TIMESTAMP = 128

  model = _atm
  selection.elementMode = Table.ElementMode.Row
  selection.intervalMode = Table.IntervalMode.Single
  peer.getTableHeader().setReorderingAllowed(false)
  peer.setColumnSelectionAllowed(false)
  peer.getColumnModel().getColumn(1).setMaxWidth(COLWIDTH_TIMESTAMP)

  def architecture: Option[Architecture] = if (selection.rows.isEmpty) {
    None
  } else {
    Some(_atm(selection.rows.min))
  }
}

