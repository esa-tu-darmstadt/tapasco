package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  edu.uci.ics.jung.visualization._

/** Paintable for JUNG2 VisualizationViewer, which depicts the main grid in the
 *  DSE graph view. Axes are utilization and design frequency; there are major
 *  gridlines in 10-step, and minor gridline in 1-step. Additionally, labels
 *  are rendered at the major gridlines' intersection with the axes.
 */
class MainViewerGrid(vv: VisualizationViewer[_, _]) extends VisualizationServer.Paintable {
  import java.awt._
  import java.awt.geom._
  var gridColor: Color = Color.gray
  var crosshairColor: Color = Color.gray

  override def useTransform: Boolean = true

  // scalastyle:off method.length
  // scalastyle:off magic.number
  override def paint(g: Graphics) {
    val mlt = vv.getRenderContext().getMultiLayerTransformer().getTransformer(Layer.LAYOUT)
    val path = new GeneralPath()
    path.moveTo(0, 0)
    path.lineTo(100, 0)
    path.lineTo(100, -100)
    path.lineTo(0, -100)
    path.lineTo(0, 0)
    for (i <- 0 until 100 by 5) {
      path.moveTo(i, 0)
      path.lineTo(i, -100)
    }
    for (i <- 0 until -100 by -1) {
      path.moveTo(0, i)
      path.lineTo(100, i)
    }
    val lens = mlt.transform(path)
    val g2d = g.asInstanceOf[Graphics2D]
    val oc = g.getColor()
    g.setColor(gridColor)
    g2d.draw(lens)

    val axis = new GeneralPath()
    axis.moveTo(0,-100)
    axis.lineTo(0,0)
    axis.lineTo(100,0)
    axis.lineTo(100,-100)
    axis.lineTo(0,-100)

    g2d.setFont(new Font("SansSerif", Font.PLAIN, 12))

    for (i <- 0 until -100 by -10) {
      axis.moveTo(0, i)
      axis.lineTo(100, i)
      val p = mlt.transform(new Point2D.Float(0, i))
      val m = "%3d".format(-i * 5)
      val w = g2d.getFontMetrics().stringWidth(m) + 5
      g2d.drawString(m, p.getX().toFloat - w, p.getY().toFloat)
    }
    for (i <- 10 until 100 by 10) {
      axis.moveTo(i, 0)
      axis.lineTo(i, -100)
      val p = mlt.transform(new Point2D.Float(i, 0))
      val m = "%3d%%".format(i)
      g2d.drawString(m, p.getX().toFloat, p.getY().toFloat + 17)
    }

    g2d.setStroke(new BasicStroke(3))
    g2d.draw(mlt.transform(axis))

    g.setColor(oc)
  }
  // scalastyle:on magic.number
  // scalastyle:on method.length
}
