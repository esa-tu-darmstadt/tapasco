package de.tu_darmstadt.cs.esa.tapasco.itapasco.view
import  scala.swing.TabbedPane

/**
 * TabbedPane containing the main tabs of iTPC:
 * For each configuration step a single pane; each pane registers
 * with the model (or submodel) they are interested in.
 **/
class ConfigurationPanel extends TabbedPane

private[itapasco] object ConfigurationPanel {
  // scalastyle:off magic.number
  final val TASK_BG_COLOR = new java.awt.Color(178, 223, 138)
  // scalastyle:on magic.number
}
