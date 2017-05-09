package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.detail
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.selection.ArchitecturesPanel
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.common._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base.Architecture
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.util.Listener
import  ArchitecturesPanel.Events._
import  scala.swing.ScrollPane

/** Detail panel for [[base.Architecture]] instances.
 *  Uses a [[common.DescriptionPropertiesTable]] to show details.
 */
class ArchitectureDetailPanel extends ScrollPane with Listener[ArchitecturesPanel.Event] {
  def update(e: ArchitecturesPanel.Event): Unit = e match {
    case ArchitectureSelected(od) => update(od)
  }

  private def update(od: Option[Architecture]): Unit = {
    viewportView = new DescriptionPropertiesTable(od)
    revalidate()
  }
}
