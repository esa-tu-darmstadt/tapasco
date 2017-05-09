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
 * @file    Platform.scala
 * @brief   Model: TPC Platform.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.threadpoolcomposer.base
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.json._
import  builder._
import  json._
import  java.nio.file._

case class Platform (
      descPath: Path,
      name: String,
      private val _tclLibrary: Path,
      part: String,
      boardPart: String,
      boardPreset: String,
      targetUtilization: Int,
      supportedFrequencies: Seq[Int],
      slotCount: Int,
      description: Option[String],
      private val _harness: Option[Path],
      private val _api: Option[Path],
      private val _testbenchTemplate: Option[Path],
      private val _benchmark: Option[Path]
    ) extends Description(descPath) {
  val tclLibrary: Path                = resolve(_tclLibrary)
  val harness: Option[Path]           = _harness map (resolve _)
  val api: Option[Path]               = _api map (resolve _)
  val testbenchTemplate: Option[Path] = _testbenchTemplate map (resolve _)
  val benchmark: Option[Benchmark]    = _benchmark flatMap (p => Benchmark.from(resolve(p)).toOption)
  require (mustExist(tclLibrary), "Tcl library %s does not exist".format(tclLibrary.toString))
  harness foreach           { p => require(mustExist(p), "harness file %s does not exist".format(p.toString)) }
  api foreach               { p => require(mustExist(p), "api file %s does not exist".format(p.toString)) }
  testbenchTemplate foreach { p => require(mustExist(p), "testbench template %s does not exist".format(p.toString)) }
}

object Platform extends Builds[Platform]
