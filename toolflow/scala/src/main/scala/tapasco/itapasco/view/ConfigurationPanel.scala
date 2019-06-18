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
