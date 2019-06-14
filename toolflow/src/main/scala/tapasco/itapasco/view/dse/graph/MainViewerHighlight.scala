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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  edu.uci.ics.jung.visualization._

/** JUNG2 VisualizationViewer Paintable which depicts the current viewport in the
 *  [[globals.Graph.mainViewer]] within the [[globals.Graph.satViewer]]. Done by
 *  filling the transformed rectangle with brighter version of the background color.
 */
class MainViewerHighlight(vv: VisualizationViewer[_, _]) extends VisualizationServer.Paintable {
  import java.awt._
  import java.awt.geom._

  def useTransform(): Boolean = true

  def paint(g: Graphics): Unit = {
    val mlt = vv.getRenderContext().getMultiLayerTransformer().getTransformer(Layer.LAYOUT)
    val br = mlt.transform(vv.getRenderContext.getMultiLayerTransformer().inverseTransform(
      new GeneralPath(vv.getBounds())
    ))
    val g2d = g.asInstanceOf[Graphics2D]
    val oldColor = g.getColor()
    g.setColor(vv.getBackground().brighter().brighter())
    g2d.fill(br)
    g.setColor(oldColor)
  }
}
