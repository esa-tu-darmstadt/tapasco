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
 * @file    Benchmark.scala
 * @brief   Model: TPC IP Benchmark.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  builder._
import  java.time.LocalDateTime
import  java.nio.file._

final case class LibraryVersions(platform: String, tapasco: String)
final case class Host(machine: String, node: String, operatingSystem: String, release: String, version: String)
final case class TransferSpeedMeasurement(chunkSize: Int, read: Double, write: Double, readWrite: Double)
final case class Benchmark (
    descPath: Path,
    timestamp: LocalDateTime,
    host: Host,
    libraryVersions: LibraryVersions,
    transferSpeed: Seq[TransferSpeedMeasurement],
    interruptLatency: Double
  ) extends Description(descPath)

object Benchmark extends Builds[Benchmark]
