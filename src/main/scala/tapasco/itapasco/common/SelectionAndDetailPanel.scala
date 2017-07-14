package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  scala.swing._
import  scala.swing.BorderPanel.Position._
import  javax.swing.border.Border

/**
 * Basic two element panel type for most iTPC panes:
 * A selection component displayed at top, a detail component at the bottom,
 * showing details for the currently selected items in the selection component.
 *
 * @constructor Create new instance.
 * @param selection Selection component (top).
 * @param detail Detail component (bottom).
 */
class SelectionAndDetailPanel(selection: Component, detail: Component)
    extends SplitPane(Orientation.Horizontal) {
  private final val BORDER_SZ        = 5
  private final val SCROLL_BORDER_SZ = 2
  protected val selectionBorder: Border =
    Swing.CompoundBorder(Swing.EtchedBorder, Swing.EmptyBorder(BORDER_SZ))
  protected val selectionScrollBorder: Border = Swing.EmptyBorder(SCROLL_BORDER_SZ)
  protected val detailBorder: Border = Swing.CompoundBorder(Swing.EtchedBorder, Swing.EmptyBorder(BORDER_SZ))

  leftComponent = new BorderPanel {
    layout(new ScrollPane(selection) { border = selectionScrollBorder }) = Center
    border = selectionBorder
  }
  rightComponent = new BorderPanel {
    layout(detail) = Center
    border = detailBorder
  }

  border = Swing.EmptyBorder(BORDER_SZ)
  Swing.onEDT { dividerLocation = 0.5 }
  listenTo(this)
  reactions += {
    case scala.swing.event.UIElementResized(_) => dividerLocation = .5
  }
}

