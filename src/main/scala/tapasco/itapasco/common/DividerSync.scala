package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  scala.swing.Reactor
import  scala.swing.event._

/** Synchronizes the split locations of two [[TripleSplitPanel]] instances.
 *  @constructor Create new instance.
 *  @param tsp0 First split panel.
 *  @param tsp1 Second split panel.
 */
class DividerSync(tsp0: TripleSplitPanel, tsp1: TripleSplitPanel) extends Reactor {
  listenTo(tsp0.left, tsp0.right, tsp1.left, tsp1.right)
  reactions += {
    case UIElementResized(e) => e match {
      case tsp0.left   => tsp1.dividerLocations.left  = tsp0.dividerLocations.left
      case tsp0.right  => tsp1.dividerLocations.right = tsp0.dividerLocations.right
      case tsp1.left   => tsp0.dividerLocations.left  = tsp1.dividerLocations.left
      case tsp1.right  => tsp0.dividerLocations.right = tsp1.dividerLocations.right
      case _           => {}
    }
  }
}
