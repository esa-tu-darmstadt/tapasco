package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.base.Architecture
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  javax.swing.table.AbstractTableModel
import  FileAssetManager.Events._
import  Entities._

private final class ArchitecturesTableModel extends AbstractTableModel {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _configListener = new Listener[Config.Event] {
    def update(e: Config.Event): Unit = fireTableDataChanged()
  }
  private[this] val _jobListener = new Listener[Job.Event] {
    def update(e: Job.Event): Unit = fireTableDataChanged()
  }
  private[this] val _entityListener = new Listener[FileAssetManager.Event] {
    def update(e: FileAssetManager.Event): Unit = e match {
      case BasePathChanged(`Architectures`, _)  => fireTableDataChanged()
      case EntityChanged(`Architectures`, _, _) => fireTableDataChanged()
      case _ => {}
    }
  }
  Config += _configListener
  Job += _jobListener
  FileAssetManager += _entityListener

  override def getColumnCount(): Int = 2
  override def getColumnName(col: Int): String = if (col == 0) "Architecture" else "Use"
  override def getRowCount(): Int = FileAssetManager.entities.architectures.size
  override def getValueAt(row: Int, col: Int): Object = if (col == 0) {
    architectureForRow(row).name
  } else {
    Job.job.architectures.contains(architectureForRow(row)): java.lang.Boolean
  }
  override def isCellEditable(row: Int, col: Int): Boolean = col == 1
  override def setValueAt(v: Object, row: Int, col: Int): Unit = {
    _logger.trace("setValueAt({}, {}, {})", v, row: java.lang.Integer, col: java.lang.Integer)
    if (v.asInstanceOf[Boolean]) {
      val as = (Job.job.architectures map (_.name)) + architectureForRow(row).name
      Job.job = Job.job.copy(_architectures = Some(as.toSeq.sorted))
    } else {
      val as = (Job.job.architectures map (_.name)) - architectureForRow(row).name
      if (as.size > 0) Job.job = Job.job.copy(_architectures = Some(as.toSeq.sorted))
    }
    fireTableDataChanged()
  }

  def apply(row: Int): Architecture = architectureForRow(row)

  private def architectureForRow(row: Int): Architecture =
    FileAssetManager.entities.architectures.toSeq.sortBy(_.name).apply(row)
}

