//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
/**
 * @file    FeatureTclPrinter.scala
 * @brief   Generates Tcl commands to add feature to a Tcl dict.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base.tcl
import  de.tu_darmstadt.cs.esa.tapasco.base.Feature
import  scala.util.Properties.{lineSeparator => NL}

class FeatureTclPrinter(prefix: String) {
  private val pre = s"dict set ${prefix}features"

  /** GenerateTcl commands to add feature to a Tcl dict.
    * @param f Feature to add.
    * @return String containing Tcls commands to write f into
    *         a dict called <prefix>features.
   **/
  def toTcl(f: Feature): String = f.props map {
    case (name, value) => s"$pre ${f.name} $name $value"
  } mkString NL

  def toTcl(fs: Seq[Feature]): String = fs.map(toTcl).mkString(NL)
}
