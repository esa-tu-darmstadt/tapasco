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

