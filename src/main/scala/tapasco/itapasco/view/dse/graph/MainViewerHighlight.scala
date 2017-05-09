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
