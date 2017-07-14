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
 * @file    Architecture.scala
 * @brief   Model: TPC Architecture.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  java.nio.file._
import  builder._

case class Architecture (
      descPath: Path,
      name: String,
      private val _tclLibrary: Path,
      description: String,
      private val _valueArgTemplate: Path,
      private val _referenceArgTemplate: Path,
      additionalSteps: Seq[String]
    ) extends Description(descPath) {
  val tclLibrary: Path = resolve(_tclLibrary)
  val valueArgTemplate: Path = resolve(_valueArgTemplate)
  val referenceArgTemplate: Path = resolve(_referenceArgTemplate)
  require (mustExist(tclLibrary), "Tcl library %s does not exist".format(tclLibrary.toString))
  require (mustExist(valueArgTemplate), "value argument template %s does not exist".format(valueArgTemplate.toString))
  require (mustExist(referenceArgTemplate), "ref argument template %s does not exist".format(referenceArgTemplate.toString))
}

object Architecture extends Builds[Architecture]
