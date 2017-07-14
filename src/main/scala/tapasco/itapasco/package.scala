package de.tu_darmstadt.cs.esa.tapasco

/** Interactive Tapasco - GUI for TPC.
 *  This package contains all classes and objects related to the interactive
 *  Tapasco GUI, which is a based on Swing. Most GUI elements
 *  loosely adhere to the Model-View-Controller pattern: UI elements publish
 *  events, controllers receive events and react on them, e.g., by modifying
 *  the Views (UI elements). The package [[itapasco.globals]] contains global
 *  application state objects, which can be modified in a decentralized
 *  manner and publish change events in turn.
 *  The [[itapasco.controller]] package contains the [[controller.ViewController]]
 *  instances, the UI elements are in the [[view]] subpackage. Most panels in
 *  the app are split into 'selection' (upper half) and 'detail' (lower half).
 *  This is also reflected in the package structure.
 **/
package object itapasco
