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
 * @file    Platform.scala
 * @brief   Model: TPC Platform.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  builder._
import  json._
import  java.nio.file._

case class Platform (
      descPath: Path,
      name: String,
      private val _tclLibrary: Path,
      part: String,
      boardPart: Option[String],
      boardPreset: Option[String],
      targetUtilization: Int,
      supportedFrequencies: Seq[Int],
      private val _slotCount: Option[Int],
      description: Option[String],
      private val _benchmark: Option[Path],
      hostFrequency: Option[Double],
      memFrequency: Option[Double]
    ) extends Description(descPath) {
  val tclLibrary: Path                = resolve(_tclLibrary)
  val benchmark: Option[Benchmark]    = _benchmark flatMap (p => Benchmark.from(resolve(p)).toOption)
  val slotCount: Int                  = _slotCount getOrElse Platform.DEFAULT_SLOTCOUNT
  require (mustExist(tclLibrary), "Tcl library %s does not exist".format(tclLibrary.toString))
}

object Platform extends Builds[Platform] {
  private final val DEFAULT_SLOTCOUNT: Int = 128
}
