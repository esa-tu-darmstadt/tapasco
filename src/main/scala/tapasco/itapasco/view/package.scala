package de.tu_darmstadt.cs.esa.tapasco.itapasco

/** iTPC loosely adheres to the 'Model-View-Controller (MVC)' paradigm; this
 *  package contains all 'View' classes, i.e., UI elements.
 *  Most views are Selection/Detail, the packages [[view.selection]] and 
 *  [[view.detail]] contain the classes in these categories. Note that some
 *  UI elements that have been reused intensively are also found in
 *  [[itapasco.common]].
 */
package object view {
  /** Base type for views. */
  type View = scala.swing.Component
}
