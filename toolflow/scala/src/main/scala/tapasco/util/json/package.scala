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
/**
 * @file     json.scala
 * @brief    Package containing Json Reads/Writes/Formats for Json SerDes.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.e)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  play.api.libs.json._
import  play.api.libs.functional.syntax._

package object json {
  implicit val resourcesEstimateFormat: Format[ResourcesEstimate] = (
    (__ \ "Slices").format[Int] ~
    (__ \ "LUTs").format[Int] ~
    (__ \ "FlipFlops").format[Int] ~
    (__ \ "DSPs").format[Int] ~
    (__ \ "BRAM").format[Int]
  ) (ResourcesEstimate.apply _, unlift(ResourcesEstimate.unapply _))

  implicit val areaEstimateFormat: Format[AreaEstimate] = (
    (__ \ "Resources").format[ResourcesEstimate] ~
    (__ \ "Available").format[ResourcesEstimate]
  ) (AreaEstimate.apply _, unlift(AreaEstimate.unapply _))
}
