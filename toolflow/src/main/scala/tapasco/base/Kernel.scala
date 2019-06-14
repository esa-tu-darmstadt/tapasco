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
 * @file    Kernel.scala
 * @brief   Model: TPC Kernel.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  java.nio.file._
import  builder._

case class Kernel (
      descPath: Path,
      name: String,
      topFunction: String,
      id: Kernel.Id,
      version: String,
      private val _files: Seq[Path],
      private val _testbenchFiles: Seq[Path],
      description: Option[String],
      compilerFlags: Seq[String],
      testbenchCompilerFlags: Seq[String],
      args: Seq[Kernel.Argument],
      private val _otherDirectives: Option[Path]
    ) extends Description(descPath) {
  val files: Seq[Path]              = _files map (resolve _)
  val testbenchFiles: Seq[Path]     = _testbenchFiles map (resolve _)
  val otherDirectives: Option[Path] = _otherDirectives map (resolve _)
  files foreach           { f => require(mustExist(f), "source file %s does not exist".format(f.toString)) }
  testbenchFiles foreach  { f => require(mustExist(f), "testbench file %s does not exist".format(f.toString)) }
  otherDirectives foreach { p => require(mustExist(p), "other directives file %s does not exist".format(p.toString)) }
}

object Kernel extends Builds[Kernel] {
  type Id = Int
  sealed trait PassingConvention
  object PassingConvention {
    final case object ByValue extends PassingConvention     { override def toString(): String = "by value" }
    final case object ByReference extends PassingConvention { override def toString(): String = "by reference" }

    def apply(passingConvention: String): PassingConvention =
      if (passingConvention.isEmpty) ByValue else passingConvention.toLowerCase match {
        case "by reference" => ByReference
        case "by value"     => ByValue
        case x              => throw new Exception("invalid passing convention: " + x)
      }
  }

  final case class Argument(
    name: String,
    passingConvention: PassingConvention
  )
}
