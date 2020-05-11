/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
/**
  * @file Feature.scala
  * @brief TPC Architecture / Platform features.
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.base

sealed case class Feature(val name: String, val props: Feature.FMap) {
  def unapply: Option[(String, Feature.FMap)] = Some((name, props))
}

object Feature {
  def apply(name: String, props: FMap): Feature = {
    val lp = props.value map { case (k, v) => k.toLowerCase -> v }
    new Feature(
      name,
      if (lp.get("enabled").nonEmpty) FMap(lp) else FMap(lp + ("enabled" -> FString("true")))
    )
  }

  def unapply(f: Feature): Option[(String, FMap)] = f.unapply


  // Internel Classes for Structure
  sealed trait FValue {
    def value: Any

    def toTCL: String

    def toJson: String
  }

  // Corresponding to Json Object
  case class FMap(in: Map[String, FValue]) extends FValue {
    override def value: Map[String, FValue] = in

    override def toTCL: String = {
      val map = for {(k, v) <- in} yield s""""$k" ${v.toTCL}"""
      map.fold("{")(_ ++ " " ++ _) + "}"
    }

    override def toJson: String = {
      val map = for {(k, v) <- in} yield s""""$k" : ${v.toJson}"""
      "{" + map.fold("")(_ ++ ", " ++ _).drop(1) + "}"
    }
  }

  // Corresponding to Json Array
  case class FList(in: List[FValue]) extends FValue {
    override def value: List[FValue] = in

    override def toTCL: String = {
      val list = for {j <- in} yield s"${j.toTCL}"
      list.fold("{")(_ ++ " " ++ _) + "}"
    }

    override def toJson: String = {
      val list = for {j <- in} yield s"""${j.toJson}"""
      "[" + list.fold("")(_ ++ ", " ++ _).drop(1) + "]"
    }
  }

  // Corresponding to any other Json Value
  case class FString(in: String) extends FValue {
    override def value: String = in

    override def toTCL: String = s""""$in""""

    override def toJson: String = s""""$in""""
  }

}
