package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph._
import  edu.uci.ics.jung.algorithms.layout.StaticLayout
import  java.awt.geom.Point2D
import  com.google.common.base.Function

/** Defines a static coordinate space for instances of [[model.DesignSpaceGraph]].
 *    - `X` is area utilization in percent
 *    - `Y` is negative of design frequency in MHz divided by 5
 *  The latter deserves explanation: The overall graph shape should be square;
 *  utilization ranges from 0-100 (in valid cases), while design frequencies range
 *  from 0-500 MHz, thus the rescaling.
 *
 *  @todo Need to extend frequency range for UltraScale(+) devices?
 *  @todo Check if this is the right package?
 *
 *  @constructor Create new instance.
 *  @param g [[model.DesignSpaceGraph]] to associate with.
 */
class DesignSpaceStaticLayout(g: DesignSpaceGraph) extends StaticLayout(g, new Function[N, Point2D] {
    def apply(e: N): Point2D = {
      val util = g.utilization(e) map (_.utilization)
      assert (util.nonEmpty, "area estimate must be available for all elements")
      new Point2D.Double(util getOrElse 0.0, -e.frequency / 5.0)
    } }) {
  // set all nodes locked
  override def isLocked(v: N): Boolean = true
  override def setLocation(v: N, location: Point2D): Unit = {}
}
