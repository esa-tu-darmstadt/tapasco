//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
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
