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
 * @file    Core.scala
 * @brief   Model: TPC IP Core.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  java.nio.file._
import  builder._

case class Core (
      descPath: Path,
      private val _zipPath: Path,
      name: String,
      id: Kernel.Id,
      version: String,
      private val _target: TargetDesc,
      description: Option[String],
      averageClockCycles: Option[Int]
    ) extends Description(descPath) {
  val zipPath: Path = resolve(_zipPath).toAbsolutePath
  require(mustExist(zipPath), "zip file %s does not exist".format(zipPath.toString))
  lazy val target: Target = _target
}

object Core extends Builds[Core]
