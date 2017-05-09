//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file    FeatureTclPrinter.scala
 * @brief   Generates Tcl commands to add feature to a Tcl dict.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.threadpoolcomposer.base.tcl
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base.Feature
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base.Feature._
import  scala.util.Properties.{lineSeparator => NL}

class FeatureTclPrinter(prefix: String) {
  private val pre = "dict set " + prefix + "features "

  /** GenerateTcl commands to add feature to a Tcl dict.
    * @param f Feature to add.
    * @return String containing Tcls commands to write f into
    *         a dict called <prefix>features.
   **/
  def toTcl(f: Feature): String = f match {
    case LED(enabled) => pre + "LED enabled " + enabled
    case OLED(enabled) => pre + "OLED enabled " + enabled
    case Cache(enabled, size, associativity) => Seq(
      pre + "Cache enabled " + enabled,
      pre + "Cache size " + size,
      pre + "Cache associativity " + associativity).mkString(NL)
    case Debug(enabled, depth, stages, useDefaults, nets) => Seq(
      pre + "Debug enabled " + enabled,
      if (depth.isEmpty) "" else pre + "Debug depth " + depth.get,
      if (stages.isEmpty) "" else pre + "Debug stages " + stages.get,
      if (useDefaults.isEmpty) "" else pre + "Debug use_defaults " + useDefaults.get,
      if (nets.isEmpty) "" else pre + "Debug nets [list " + nets.get.map(n => "{" + n + "}").mkString(" ") + "] "
      ).mkString(NL)

    case _ => "unknown feature"
  }

  def toTcl(fs: Seq[Feature]): String = fs.map(toTcl).mkString(NL)
}
