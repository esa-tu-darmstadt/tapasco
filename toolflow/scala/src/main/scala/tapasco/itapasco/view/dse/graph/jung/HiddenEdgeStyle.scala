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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph.jung
import  edu.uci.ics.jung.visualization.RenderContext
import  edu.uci.ics.jung.algorithms.layout.Layout
import  edu.uci.ics.jung.visualization.renderers._

final class HiddenEdgeStyle[V, E] extends EdgeStyle[V, E] {
  override def renderer: Option[Renderer.Edge[V, E]] = Some(new BasicEdgeRenderer[V, E] {
    // do not draw any edges
    override def paintEdge(ctx: RenderContext[V, E], l: Layout[V, E], e: E): Unit = {}
  })
}

