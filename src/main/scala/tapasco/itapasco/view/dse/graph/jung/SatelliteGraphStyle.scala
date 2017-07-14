package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph.jung
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph.RunStates._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.ComposeResult
import  edu.uci.ics.jung.visualization._
import  java.awt.{Color, Paint, Shape}
import  java.awt.geom._
import  com.google.common.base.Function

class SatelliteGraphStyle(g: DesignSpaceGraph) extends GraphStyle[N, E] {
  import SatelliteGraphStyle._

  class SatelliteGraphVertexStyle(vv: VisualizationViewer[N, E]) extends VertexStyle[N, E] {
    override def shape: Option[Function[N, Shape]] = Some(new Function[N, Shape] {
      def apply(n: N): Shape = NODE_SHAPE
    })

    override def drawPaint: Option[Function[N, Paint]] = Some(new Function[N, Paint] {
      def apply(n: N): Paint = NODE_DRAW
    })

    override def fillPaint: Option[Function[N, Paint]] = Some(new Function[N, Paint] {
      def apply(n: N): Paint = g.state(n) map (_ match {
        case Running  => NODE_FILL_RUNNING
        case Finished => if (isSuccess(n)) NODE_FILL_FINISHED_SUCCESS else NODE_FILL_FINISHED_ERROR
        case Pruned   => NODE_FILL_PRUNED
        case _        => if (vv.getPickedVertexState().isPicked(n)) NODE_FILL_PICKED else NODE_FILL_DEFAULT
      }) getOrElse (if (vv.getPickedVertexState().isPicked(n)) NODE_FILL_PICKED else NODE_FILL_DEFAULT)
    })

    private def isSuccess(n: N): Boolean = g.result(n) map {
      _.result == ComposeResult.Success
    } getOrElse false
  }

  override def apply(vv: VisualizationViewer[N, E]): Unit = {
    new SatelliteGraphVertexStyle(vv)(vv)
    new HiddenEdgeStyle()(vv)
  }
}

private object SatelliteGraphStyle {
  // scalastyle:off magic.number
  private final val NODE_SHAPE                 = new Rectangle2D.Float(-2f, -2f, 4f, 4f)
  private final val NODE_FILL_FINISHED_SUCCESS = new Color(178, 223, 138).darker()
  private final val NODE_DRAW                  = new Color(0, 0, 0, 0)
  // scalastyle:on magic.number
  private final val NODE_FILL_DEFAULT          = Color.white
  private final val NODE_FILL_RUNNING          = Color.red.brighter()
  private final val NODE_FILL_FINISHED_ERROR   = Color.white
  private final val NODE_FILL_PRUNED           = Color.gray
  private final val NODE_FILL_PICKED           = Color.red
}
