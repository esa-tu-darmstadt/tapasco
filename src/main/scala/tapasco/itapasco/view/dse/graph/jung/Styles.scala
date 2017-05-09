package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph.jung
import  edu.uci.ics.jung.visualization._
import  edu.uci.ics.jung.visualization.renderers._
import  com.google.common.base.Function
import  java.awt.{Paint, Shape, Stroke}

trait GraphStyle[V, E] {
  def vertexStyle(vv: VisualizationViewer[V, E]): Option[VertexStyle[V, E]] = None
  def edgeStyle(vv: VisualizationViewer[V, E]): Option[EdgeStyle[V, E]]     = None
  def apply(vv: VisualizationViewer[V, E]): Unit = {
    vertexStyle(vv) foreach { _.apply(vv) }
    edgeStyle(vv) foreach   { _.apply(vv) }
  }
}

trait VertexStyle[V, E] {
  def fillPaint: Option[Function[V, Paint]]            = None
  def drawPaint: Option[Function[V, Paint]]            = None
  def stroke: Option[Function[V, Stroke]]              = None
  def shape: Option[Function[V, Shape]]                = None
  def tooltip: Option[Function[V, String]]             = None
  def renderer: Option[Renderer.Vertex[V, E]]          = None
  def labelRenderer: Option[Renderer.VertexLabel[V,E]] = None

  def apply(vv: VisualizationViewer[V, E]): Unit = {
    fillPaint foreach { f      => vv.getRenderContext().setVertexFillPaintTransformer(f) }
    drawPaint foreach { f      => vv.getRenderContext().setVertexDrawPaintTransformer(f) }
    stroke foreach { s         => vv.getRenderContext().setVertexStrokeTransformer(s) }
    shape foreach { s          => vv.getRenderContext().setVertexShapeTransformer(s) }
    tooltip foreach { tt       => vv.setVertexToolTipTransformer(tt) }
    renderer foreach { r       => vv.getRenderer().setVertexRenderer(r) }
    labelRenderer foreach { lr => vv.getRenderer().setVertexLabelRenderer(lr) }
  }
}

trait EdgeStyle[V, E] {
  def label: Option[Function[E, String]]             = None
  def stroke: Option[Function[E, Stroke]]            = None
  def drawPaint: Option[Function[E, Paint]]          = None
  def renderer: Option[Renderer.Edge[V,E]]           = None
  def labelRenderer: Option[Renderer.EdgeLabel[V,E]] = None

  def apply(vv: VisualizationViewer[V, E]): Unit = {
    label foreach { l          => vv.getRenderContext().setEdgeLabelTransformer(l) }
    stroke foreach { s         => vv.getRenderContext().setEdgeStrokeTransformer(s) }
    drawPaint foreach { d      => vv.getRenderContext().setEdgeDrawPaintTransformer(d) }
    renderer foreach { r       => vv.getRenderer().setEdgeRenderer(r) }
    labelRenderer foreach { lr => vv.getRenderer().setEdgeLabelRenderer(lr) }
  }
}

