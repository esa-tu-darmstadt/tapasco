//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base.Platform
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  javax.swing.table.AbstractTableModel
import  FileAssetManager.Events._
import  Entities._

private final class PlatformsTableModel extends AbstractTableModel {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _configListener = new Listener[Config.Event] {
    def update(e: Config.Event): Unit = fireTableDataChanged()
  }
  private[this] val _jobListener = new Listener[Job.Event] {
    def update(e: Job.Event): Unit = fireTableDataChanged()
  }
  private[this] val _entityListener = new Listener[FileAssetManager.Event] {
    def update(e: FileAssetManager.Event): Unit = e match {
      case BasePathChanged(`Platforms`, _)  => fireTableDataChanged()
      case EntityChanged(`Platforms`, _, _) => fireTableDataChanged()
      case _ => {}
    }
  }
  Config += _configListener
  Job += _jobListener
  FileAssetManager += _entityListener

  override def getColumnCount(): Int = 2
  override def getColumnName(col: Int): String = if (col == 0) "Platform" else "Use"
  override def getRowCount(): Int = FileAssetManager.entities.platforms.size
  override def getValueAt(row: Int, col: Int): Object = if (col == 0) {
    platformForRow(row).name
  } else {
    Job.job.platforms.contains(platformForRow(row)): java.lang.Boolean
  }
  override def isCellEditable(row: Int, col: Int): Boolean = col == 1
  override def setValueAt(v: Object, row: Int, col: Int): Unit = {
    _logger.trace("setValueAt({}, {}, {})", v, row: java.lang.Integer, col: java.lang.Integer)
    if (v.asInstanceOf[Boolean]) {
      val ps  = (Job.job.platforms map (_.name)) + platformForRow(row).name
      Job.job = Job.job.copy(_platforms = Some(ps.toSeq.sorted))
    } else {
      val ps  = (Job.job.platforms map (_.name)) - platformForRow(row).name
      if (ps.size > 0) Job.job = Job.job.copy(_platforms = Some(ps.toSeq.sorted))
    }
    fireTableDataChanged()
  }

  def apply(row: Int): Platform = platformForRow(row)

  private def platformForRow(row: Int): Platform =
    FileAssetManager.entities.platforms.toSeq.sortBy(_.name).apply(row)
}
