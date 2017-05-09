package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  scala.swing._
import  javax.swing.table.{AbstractTableModel, TableModel}

/**
 * Make a scala.swing.Table non-editable.
 * Can be applied to Table instances to set a number of properties to prevent
 * editing user interactions (e.g., editing of cells, reordering of columns).
 **/
object NonEditable {
  /**
   * Make a non-editable AbstractTableModel from the given TableModel.
   * @param m TableModel instance to use.
   * @return AbstractTableModel that defers to m, but disables editing.
   **/
  def apply(m: TableModel): TableModel = new AbstractTableModel {
    override def getColumnName(column: Int) = m.getColumnName(column)
    def getRowCount() = m.getRowCount()
    def getColumnCount() = m.getColumnCount()
    def getValueAt(row: Int, col: Int) = m.getValueAt(row, col)
    override def isCellEditable(row: Int, col: Int) = false
  }

  /**
   * Make a non-editable Table from the given Table instance.
   * @param m Table instance to make non-editable.
   * @return Table instance that defers to m, but disables all editing.
   **/
  def apply(m: Table): Table = {
    m.model = NonEditable(m.model)
    m.peer.getTableHeader().setReorderingAllowed(false)
    m
  }
}
