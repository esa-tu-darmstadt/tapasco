package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  edu.uci.ics.jung.visualization._
import  java.awt.geom.Point2D

/** Mix-in trait to add scaling and centering helpers for a JUNG2 VisualizationViewer.
 *  View detail can be controlled via two points, [[center]] and [[scalePoint]]:
 *  Changing the center point will translate the view matrix to move the point into
 *  the center of the component. The scale point defines the upper-right corner of the
 *  visible detail, changing it wil change the scale to fit. Both are in given in
 *  graph coordinates (not view coordinates).
 *
 *  @tparam V Node/vertex type.
 *  @tparam E Edge type.
 */
trait Centering[V, E] {
  protected var _center: Point2D     = new Point2D.Double(50.0, -50.0)
  protected var _scalePoint: Point2D = new Point2D.Double(105.0, -180.0)

  def center: Point2D = _center
  def center_=(p: Point2D): Unit = {
    _center = p
    Centering.recenter(vv, _center)
    vv.repaint()
  }
  def recenter() { Centering.recenter(vv, _center) }

  def scalePoint: Point2D = _scalePoint
  def scalePoint_=(p: Point2D): Unit = {
    _scalePoint = p
    Centering.rescale(vv, _scalePoint)
    vv.repaint()
  }
  def rescale() { Centering.rescale(vv, _scalePoint) }

  protected def vv: VisualizationViewer[V, E]
}

object Centering {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /** Center the given VisualizationViewer on the given point.
   *  @param vv JUNG2 VisualizationViewer to re-center.
   *  @param center Point in graph coordinates to center on.
   */
  def recenter(vv: VisualizationViewer[_, _], center: Point2D) {
    val mlt = vv.getRenderContext().getMultiLayerTransformer()
    logger.trace("center: {}", vv.getCenter())
    val vc = mlt.inverseTransform(vv.getCenter())
    val tx = vc.getX() - center.getX()
    val ty = vc.getY() - center.getY()
    mlt.getTransformer(Layer.LAYOUT).translate(tx, ty)
  }

  /** Rescale the given VisualizationViewer such that `scalePoint` is the
   *  upper-right corner of the visible view.
   *  @param vv JUNG2 VisualizationViewer to re-scale.
   *  @param scalePoint Point in graph coordinates to rescale as upper-right corner.
   */
  def rescale(vv: VisualizationViewer[_, _], scalePoint: Point2D) {
    val mlt = vv.getRenderContext().getMultiLayerTransformer().getTransformer(Layer.LAYOUT)
    val mvt = vv.getRenderContext().getMultiLayerTransformer().getTransformer(Layer.VIEW)
    val osf = mlt.getScale()
    logger.trace("scale: {}", osf)
    val vc = mlt.inverseTransform(vv.getCenter())
    val sf = Seq(vv.getBounds().width  / (scalePoint.getX() * osf),
                 vv.getBounds().height / (scalePoint.getY() * osf)).min
    logger.trace("center: {}", vv.getCenter())
    mlt.scale(sf, sf, mvt.inverseTransform(vv.getCenter()))
  }
}
