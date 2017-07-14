package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import de.tu_darmstadt.cs.esa.tapasco.base._
import scala.swing.Table
import javax.swing.table.AbstractTableModel

/**
 * A DescriptionPropertiesTable is a scala.swing.Table heir that formats and
 * displays properties that are common to all [[base.Description]]
 * instances.
 *
 * @constructor Create new instance for given [[base.Description]].
 * @param od [[base.Description]] instance (optional).
 */
class DescriptionPropertiesTable(od: Option[Description]) extends Table(
    DescriptionPropertiesTable.descToData(od),
    Seq("Property", "Value")) {
  private val m = model
  model = new AbstractTableModel {
    override def isCellEditable(row: Int, col: Int): Boolean = false
    override def getColumnName(col: Int): String = m.getColumnName(col)
    def getColumnCount(): Int = m.getColumnCount()
    def getRowCount(): Int = m.getRowCount()
    def getValueAt(row: Int, col: Int): Object = m.getValueAt(row, col)
  }

  if (rowCount > 0) {
    val cols = 0 until peer.getColumnCount() map { i => (i, peer.getColumnModel().getColumn(i)) }
    cols foreach { case (cidx, col) =>
      val maxwidth  = col.getMaxWidth()
      val bestwidth = (for {
        ridx <- 0 until rowCount
        c = peer.prepareRenderer(peer.getCellRenderer(ridx, cidx), ridx, cidx)
      } yield c.getPreferredSize().width + peer.getIntercellSpacing().width).max
      col.setPreferredWidth(if (bestwidth > maxwidth) maxwidth else bestwidth)
    }
  }

  peer.getTableHeader().setReorderingAllowed(false)
}

private object DescriptionPropertiesTable {
  def descToData(od: Option[Description]): Array[Array[Any]] =
    od map (descToData _) getOrElse Array(Array("", ""))

  def descToData(d: Any): Array[Array[Any]] = d match {
    case o: Option[_] => o map (descToData _) getOrElse Array[Array[Any]]()
    case a: Architecture => Array(
      Array("Name", a.name),
      Array("Description", a.description),
      Array("Path to description", a.descPath),
      Array("TclLibrary", a.tclLibrary)
    ): Array[Array[Any]]
    case p: Platform => Array[Array[Any]](
      Array("Name", p.name),
      Array("Description", p.description),
      Array("Path to description", p.descPath),
      Array("Part", p.part),
      Array("BoardPart", p.boardPart),
      Array("Target Utilization (% of LUTs)", p.targetUtilization),
      Array("TclLibrary", p.tclLibrary)) ++ descToData(p.benchmark)
    case bm: Benchmark => Array[Array[Any]](
      Array("Benchmark Timestamp", bm.timestamp),
      Array("Host Machine", bm.host.machine),
      Array("Host Node", bm.host.node),
      Array("Host OS", bm.host.operatingSystem),
      Array("Host OS Release", bm.host.release),
      Array("Host OS Version", bm.host.version),
      Array("libtapasco", bm.libraryVersions.tapasco),
      Array("libplatform", bm.libraryVersions.platform))
    case core: Core => Array(
      Array("Name", core.name),
      Array("Description", core.description),
      Array("Path to description", core.descPath),
      Array("ID", core.id),
      Array("Version", core.version),
      Array("Path to .zip", core.zipPath.toString),
      Array("Clock Cycles (avg)", core.averageClockCycles getOrElse "N/A")
    ): Array[Array[Any]]
    case kernel: Kernel => Array(
      Array("Name", kernel.name),
      Array("Description", kernel.description),
      Array("Path to description", kernel.descPath),
      Array("ID", kernel.id),
      Array("Version", kernel.version)
    ): Array[Array[Any]]
    case _ => throw new Exception("invalid description received")
  }
}
