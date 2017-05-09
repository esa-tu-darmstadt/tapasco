package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.PlatformsPanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  de.tu_darmstadt.cs.esa.tapasco.base.Platform
import  PlatformsPanel.Events._

/** PlatformDetailPanel shows details for a [[base.Platform]] instance.
 *  On top there is a [[common.DescriptionPropertiesTable]] instance showing
 *  details of the description itself. Below there is a chart of the average
 *  transfer speeds achieved by the platform across different chunk sizes.
 *  
 *  @see [[chart.PlatformBenchmarkChart]]
 */
class PlatformDetailPanel extends GridBagPanel with Listener[PlatformsPanel.Event] {
  private[this] var tbl = new DescriptionPropertiesTable(None)
  private[this] val upper = new Constraints {
    gridx = 0
    gridy = 0
    weightx = 1.0
    weighty = 0.3
    fill = GridBagPanel.Fill.Both
  }
  private[this] val lower = new Constraints {
    gridx = 0
    gridy = 1
    weightx = 1.0
    weighty = 0.7
    fill = GridBagPanel.Fill.Both
  }

  private def update(op: Option[Platform]): Unit = Swing.onEDT {
    layout.clear()
    tbl = new DescriptionPropertiesTable(op)
    layout(new ScrollPane(tbl)) = upper
    op map { p =>
      p.benchmark map { bm => layout(new PlatformBenchmarkChart(bm)) = lower }
    }

    revalidate()
  }

  def update(e: PlatformsPanel.Event): Unit = e match {
    case PlatformSelected(op: Option[Platform]) => update(op)
  }
}

