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
 * @file    Feature.scala
 * @brief   TPC Architecture / Platform features.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base

sealed case class Feature(val name: String, val props: Map[String, String]) {
  def unapply: Option[(String, Map[String, String])] = Some((name, props))
}

object Feature {
  def apply(name: String, props: Map[String, String]): Feature = {
    val lp = props map { case (k, v) => k.toLowerCase -> v }
    new Feature(
      name,
      if (lp.get("enabled").nonEmpty) lp else lp + ("enabled" -> "true")
    )
  }

  def unapply(f: Feature): Option[(String, Map[String, String])] = f.unapply
}
