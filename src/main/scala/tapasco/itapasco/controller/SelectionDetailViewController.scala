package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.SelectionAndDetailPanel
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view._

/** View controller for [[common.SelectionAndDetailPanel]] views.
 *  Provides a basic view controller for selection-detail panels which consist
 *  of a 'selection' part on top, where user can select or configure something,
 *  and a 'detail' part below, where details for the currently selected entity
 *  are displayed.
 *
 *  @see [[common.SelectionAndDetailPanel]]
 *
 *  @constructor Create new instance from given selection and detail controllers.
 *  @param selection Selection view controller (top).
 *  @param detail Detail view controller (bottom).
 */
class SelectionDetailViewController(val selection: ViewController, val detail: ViewController) extends ViewController {
  override val view: View = new SelectionAndDetailPanel(selection.view, detail.view)
  override val controllers: Seq[ViewController] = Seq(selection, detail)
}

object SelectionDetailViewController {
  /** Factory method from [[view.View]] instances.
   *  Instantiates minimal [[ViewController]] instances for the views and
   *  produces a [[SelectionDetailViewController]].
   *
   *  @param selectionView Selection view.
   *  @param detailView Detail view.
   */
  def apply(selectionView: View, detailView: View): SelectionDetailViewController =
    new SelectionDetailViewController(ViewController(selectionView), ViewController(detailView))
}
