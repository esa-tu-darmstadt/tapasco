package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  edu.uci.ics.jung.visualization._

/** JUNG2 VisualizationViewer Paintable which renders the grid for [[globals.Graph.satViewer]].
 *  The axes are drawn in bold + white, the rest of the grid is 10-step in dotted gray. 
 */
class SatelliteViewerGrid(vv: VisualizationViewer[_, _]) extends VisualizationServer.Paintable {
  import java.awt._
  import java.awt.geom._

  def useTransform(): Boolean = true

  def paint(g: Graphics): Unit = {
    val mt = vv.getRenderContext().getMultiLayerTransformer()
    // current bounding rect in DS coordinates
    val br = mt.inverseTransform( new GeneralPath(vv.getBounds()) )
    val g2d = g.asInstanceOf[Graphics2D]
    val oldColor = g.getColor()
    g.setColor(Color.gray)
    g2d.setStroke(new BasicStroke(1f, BasicStroke.CAP_SQUARE, BasicStroke.JOIN_MITER,
      10f, Array(3f, 2f), 1f))
    val nbr = br.getBounds()
    // scalastyle:off magic.number
    for (i <- -10 to -500 by -10) {
      val p = new GeneralPath()
      p.moveTo(nbr.x, i)
      p.lineTo(nbr.x + nbr.width, i)
      g2d.draw(mt.transform(p))
    }
    for (i <- 10 to 100 by 10) {
      val p = new GeneralPath()
      p.moveTo(i, nbr.y)
      p.lineTo(i, nbr.y + nbr.height)
      g2d.draw(mt.transform(p))
    }
    // scalastyle:on magic.number

    g.setColor(Color.white)
    g2d.setStroke(new BasicStroke(2f))
    val p = new GeneralPath()
    p.moveTo(nbr.x, 0)
    p.lineTo(nbr.x + nbr.width, 0)
    p.moveTo(0, nbr.y)
    p.lineTo(0, nbr.y + nbr.height)
    g2d.draw(mt.transform(p))

    g.setColor(oldColor)
  }
}
