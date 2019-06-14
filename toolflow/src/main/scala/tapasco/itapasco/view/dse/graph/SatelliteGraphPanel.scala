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
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  edu.uci.ics.jung.visualization.VisualizationViewer
import  scala.swing.{BorderPanel, Component, Label, Swing}
import  java.awt.geom.Point2D

/** SatelliteGraphPanel shows a minimap of the design space.
 *  It depicts elements in three categories:
 *    - completed runs (white)
 *    - pruned runs (gray)
 *    - current runs (red)
 *  The current viewport oft [[globals.Graph.mainViewer]] is highlighted.
 */
class SatelliteGraphPanel extends BorderPanel with Centering[N, E] {
  _center     = new Point2D.Double(50.0, -50.0)
  _scalePoint = new Point2D.Double(105.0, -120.0)
  layout(new Label("no graph")) = BorderPanel.Position.Center
  override def vv: VisualizationViewer[N, E] = Graph.satViewer

  Graph += new Listener[Graph.Event] {
    import Graph.Events._
    def update(e: Graph.Event): Unit = e match {
      case GraphChanged => Swing.onEDT {
        val g = Component.wrap(Graph.satViewer)
        layout(g) = BorderPanel.Position.Center
        revalidate()
        repaint()
        listenTo(g)
      }
      case ExplorationChanged(ex) => ex foreach { _ += explorationListener }
      case _ => {}
    }
  }

  reactions += {
    case scala.swing.event.UIElementResized(_) =>
      recenter()
      rescale()
  }

  // listen to exploration events to update the picked vertices:
  // picked state means the element is currently running
  object explorationListener extends Listener[Exploration.Event] {
    // update picked vertices on DSE events
    def update(e: Exploration.Event): Unit = this.synchronized { e match {
        // unpick when a Run has finished
        case Exploration.Events.RunFinished(element, task) =>
          Graph.satViewer.getPickedVertexState.pick(element, false)
        // pick all elements in freshly started batch
        case Exploration.Events.BatchStarted(id, elements) =>
          Graph.satViewer.getPickedVertexState.clear()
          elements foreach { e => Graph.satViewer.getPickedVertexState.pick(e, true) }
        case _ => {}
      }
      // repaint on GUI thread
      Swing.onEDT { repaint() }
    }
  }
}
