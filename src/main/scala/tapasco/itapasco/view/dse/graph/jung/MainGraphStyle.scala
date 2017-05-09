package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph.jung
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph.RunStates._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph.Edges._
import  de.tu_darmstadt.cs.esa.tapasco.util.LogFormatter
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers._
import  edu.uci.ics.jung.algorithms.layout.Layout
import  edu.uci.ics.jung.visualization._
import  edu.uci.ics.jung.visualization.renderers._
import  com.google.common.base.Function
import  java.awt.{BasicStroke, Color, Paint, Shape, Stroke}
import  java.awt.geom._

/**
 * Main JUNG graph style for DSE graph panel:
 * Contains formatting transformers for nodes and edges.
 **/
class MainGraphStyle(g: DesignSpaceGraph, vv: VisualizationServer[N, E]) extends GraphStyle[N, E] {
  import scala.collection.JavaConverters._
  // Color definitions (turn off scalastyle magic.number, this is a bug in scalastyle)
  // scalastyle:off magic.number
  private[this] final val NODE_FILL_OPACITY          = 128
  private[this] final val NODE_FILL_FINISHED_SUCCESS = Color.black
  private[this] final val NODE_FILL_FINISHED_ERROR   = Color.gray
  private[this] final val NODE_DRAW_RUNNING: Color   = new Color(31, 120, 180)
  private[this] final val NODE_DRAW_FINISHED_SUCCESS = new Color(178, 223, 138)
  private[this] final val NODE_DRAW_FINISHED_ERROR   = new Color(166, 206, 227)
  private[this] final val NODE_DRAW_PRUNED_NONPICKED = new Color(0, 0, 0, 0)
  private[this] final val NODE_DRAW_PRUNED_PICKED    = new Color(0, 0, 0, 100)
  private[this] final val EDGE_DRAW_PRUNEDBY         = new Color(180, 35, 35)
  private[this] final val EDGE_DRAW_GENERATEDBY      = Color.black.brighter()
  // scalastyle:on magic.number
  private[this] final val NODE_STROKE_RUNNING        = .2f
  private[this] final val NODE_STROKE_PICKED         = .1f
  private[this] final val NODE_STROKE_NONPICKED      = 0f
  private[this] final val NODE_STROKE_SUCCESS        = .225f
  private[this] final val MAX_SCALE                  = 25.0

  private def mt = vv.getRenderContext().getMultiLayerTransformer()
  private def mlt = mt.getTransformer(Layer.LAYOUT)
  private def isPicked(n: N): Boolean = vv.getPickedVertexState().isPicked(n)
  private def pickeds = vv.getPickedVertexState().getPicked()
  private def isNodeInBatchPicked(id: Int): Boolean = (g.getEdges().asScala map { _ match {
    case InBatch(`id`, from, to) => isPicked(from) || isPicked(to)
    case _ => false
  }} fold false) (_ || _)
  private def scale: Double = Seq(mlt.getScale(), MAX_SCALE).min
  private def isSuccess(n: N) = g.result(n) map {
    _.result == ComposeResult.Success
  } getOrElse false

  // scalastyle:off method.length
  // scalastyle:off cyclomatic.complexity
  /**
   * Main VertexStyle for the DSE graph:
   * Open runs are round, finished ones square. Actually completed runs
   * are in gray, with the exception of successes, which are black circles.
   * Unfinished or unstarted runs are depicted with heatmap showing their
   * heuristic value in the design space.
   **/
  override def vertexStyle(vv: VisualizationViewer[N, E]): Option[VertexStyle[N, E]] =
    Some(new VertexStyle[N, E] {
      override def tooltip = Some(new Function[N, String] {
        def apply(n: N): String = "%s with u = %1.2f".format(main(n),
          g.utilization(n).get.utilization)
        def main(n: N): String = g.result(n) map (r =>
          "%s: %s".format(LogFormatter.logformat(n), r.result.toString)
        ) getOrElse LogFormatter.logformat(n)
    })

    override def fillPaint = Some(new Function[N, Paint] {
      def apply(n: N): Paint = {
        // semi-transparent heat map color
        lazy val heat = {
          val c = HeatMap.heatToColor(g.hrange._1, g.hrange._2, n.h)
            new Color(c.getRed(), c.getGreen(), c.getBlue(), NODE_FILL_OPACITY)
        }

        if (g.result(n).isEmpty || isSuccess(n)) heat else NODE_FILL_FINISHED_ERROR
      }
    })

    override def stroke = Some(new Function[N, Stroke] {
      def apply(n: N): Stroke = new BasicStroke(g.state(n) map (_ match {
        case Running => NODE_STROKE_RUNNING * scale.toFloat
        case Finished => if (isPicked(n)) {
          NODE_STROKE_PICKED * scale.toFloat
        } else if (isSuccess(n)) {
          NODE_STROKE_SUCCESS * scale.toFloat
        } else {
          NODE_STROKE_NONPICKED * scale.toFloat
        }
        case _       => if (isPicked(n)) NODE_STROKE_PICKED * scale.toFloat else NODE_STROKE_NONPICKED
      }) getOrElse 0f)
    })

    override def drawPaint = Some(new Function[N, Paint] {
      def apply(n: N): Paint = g.state(n) map (_ match {
        case Running  => NODE_DRAW_RUNNING
        case Finished => if (isSuccess(n)) NODE_DRAW_FINISHED_SUCCESS else NODE_DRAW_FINISHED_ERROR
        case Pruned   => if (isPicked(n)) NODE_DRAW_PRUNED_PICKED else NODE_DRAW_PRUNED_NONPICKED
      }) getOrElse Color.black
    })

    override def shape = Some(new Function[N, Shape] {
      final val RUN_SZ         = 0.85
      final val PRUNED_SZ      = 0.75
      private def mkRunShape   = {
        val s = RUN_SZ * scale
        val hs = s / 2.0
        new Ellipse2D.Float(-hs.toFloat, -hs.toFloat, s.toFloat, s.toFloat)
      }
      private def mkPrunedShape = {
        val s = PRUNED_SZ * scale
        val hs = s / 2.0
        new Rectangle2D.Float(-hs.toFloat, -hs.toFloat, s.toFloat, s.toFloat)
      }

      def apply(n: N): Shape = g.state(n) map (_ match {
        case Pruned   => mkPrunedShape
        case _        => if (g.result(n) map (_.result == ComposeResult.Success) getOrElse false) {
            mkRunShape
          } else {
            mkPrunedShape
          }
      }) getOrElse mkRunShape
    })
  })

  /**
   * Main EdgeStyle for DSE graph.
   **/
  override def edgeStyle(vv: VisualizationViewer[N, E]): Option[EdgeStyle[N, E]] = Some(new EdgeStyle[N, E] {
    override def label = Some(new Function[E, String] {
      import DesignSpaceGraph.Edges._
      def apply(e: E): String = e match {
        case InBatch(id, from, to)      => "Batch #%d".format(id)
        case PrunedBy(reason, from, to) => reason.toString
        case GeneratedBy(from, to)      => "Generated from"
      }
    })

    override def stroke: Option[Function[E, Stroke]] = Some(new Function[E, Stroke] {
      import DesignSpaceGraph.Edges._
      val dashedStroke = new BasicStroke(1f, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND, 10f,
          Array(4f, 2f), 0f)
      val solidStroke = new BasicStroke(1.5f)
      def apply(e: E): Stroke = e match {
        case InBatch(id, from, to)      => dashedStroke
        case PrunedBy(_, _, _)          => solidStroke
        case GeneratedBy(_, _)          => dashedStroke
      }
    })

    override def drawPaint: Option[Function[E, Paint]] = Some(new Function[E, Paint] {
      import DesignSpaceGraph.Edges._
      def apply(e: E): Paint = e match {
        case InBatch(id, _, _)          => DefaultColors(id)
        case PrunedBy(_, _, _)          => EDGE_DRAW_PRUNEDBY
        case GeneratedBy(_, _)          => EDGE_DRAW_GENERATEDBY
      }
    })

    override def renderer: Option[Renderer.Edge[N, E]] = Some(new BasicEdgeRenderer[N, E] {
      override def paintEdge(ctx: RenderContext[N, E], l: Layout[N, E], e: E): Unit = e match {
        case InBatch(id, _, _) => if (isNodeInBatchPicked(id)) {
            super.paintEdge(ctx, l, e)
          } else {}
        case PrunedBy(_, _, to) => if (pickeds.size() < 10 && isPicked(to)) {
            super.paintEdge(ctx, l, e)
          } else {}
        case GeneratedBy(from, to) => if (isPicked(from) || isPicked(to)) {
            super.paintEdge(ctx, l, e)
          } else {}
      }
    })

    override def labelRenderer: Option[Renderer.EdgeLabel[N, E]] = Some(new BasicEdgeLabelRenderer[N, E] {
      override def labelEdge(ctx: RenderContext[N, E], l: Layout[N, E], e: E, lbl: String) =
        e match {
          case InBatch(_, from, to) => if (isPicked(from) || isPicked(to)) {
              super.labelEdge(ctx, l, e, lbl)
            } else {}
          case PrunedBy(_, _, to) => if (pickeds.size() < 10 && isPicked(to)) {
              super.labelEdge(ctx, l, e, lbl)
            } else {}
          case GeneratedBy(from, to) => if (isPicked(from) || isPicked(to)) {
              super.labelEdge(ctx, l, e, lbl)
            } else {}
          case _ => {}
        }
    })
  })
  // scalastyle:on cyclomatic.complexity
  // scalastyle:on method.length
}
