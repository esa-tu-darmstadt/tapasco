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
package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher
import  scala.language.implicitConversions
import  java.nio.file.{Files, Path}

class BasePath(initialDir: Path, createOnSet: Boolean = true) extends Publisher {
  type Event = BasePath.Event
  private var path: Path = initialDir
  if (createOnSet) Files.createDirectories(initialDir)

  def apply: Path = path
  def get: Path   = path
  def set(p: Path): Unit = if (! p.equals(path)) {
    if (createOnSet) Files.createDirectories(p)
    path = p
    publish(BasePath.BasePathChanged(p))
  }
  override def toString(): String = path.toString()
}

object BasePath {
  sealed trait Event
  final case class BasePathChanged(path: Path) extends Event
  implicit def toPath(bp: BasePath): Path = bp.get
}
