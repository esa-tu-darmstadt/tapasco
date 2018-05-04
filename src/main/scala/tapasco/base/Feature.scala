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
//props
/**
 * @file    Feature.scala
 * @brief   TPC Architecture / Platform features.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base

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

  sealed trait FValue {
    def value: Any
    def toTCL: String
    def toJson: String
  }

  case class FMap(in : Map[String, FValue]) extends FValue{
    override def value: Map[String, FValue]  = in
    override def toTCL:  String = {
      val map = for{(k, v) <- in} yield s""""$k " ${v.toTCL}"""
        "{" + map + "}"
    }
    override def toJson: String = {
      val map = for{(k, v) <- in} yield s"$k : ${v.toJson}"
      "{\n" + map + "}\n"
    }
  }
  case class FList(in: List[FValue]) extends FValue{
    override def value: List[FValue] = in
    override def toTCL:  String = {
      val list = for{j <- in}yield s"${j.toTCL}"
      "{" + list +"}"
    }
    override def toJson: String = {
      val list = for{j <- in}yield s"${j.toJson}, "
        "[" + list + "]"
    }
  }
  case class FString(in : String) extends FValue{
    override def value:  String = in
    override def toTCL:  String = s""""$in""""
    override def toJson: String = in + ", "
  }
}
