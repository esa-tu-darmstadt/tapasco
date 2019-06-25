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
 * @file    Description.scala
 * @brief   Abstract base class for configuration files in TPC.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  java.nio.file._

/**
 * Abstract base class of TPC entities, which are read dynamically from files.
 * E.g., [[Platform]], [[Architecture]], [[Kernel]] etc
 * @param descPath Path to description file.
 **/
abstract class Description private[base] (descPath: Path) {
  override lazy val toString: String = PrettyPrinter.print(this)

  /** Resolves given path to absolute path via descPath (if necessary). */
  protected def resolve(p: Path): Path = if (p.isAbsolute) p else descPath.resolveSibling(p).normalize()
}
