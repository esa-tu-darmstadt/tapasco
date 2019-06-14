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
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager

final case class TargetDesc(a: String, p: String)

final case class Target(ad: Architecture, pd: Platform) {
  override def toString(): String = Seq(ad.name, pd.name) mkString "@"
}

object Target {
  def fromString(a: String, p: String): Option[Target] = for {
      ad <- (FileAssetManager.entities.architectures filter (_.name.equals(a))).headOption
      pd <- (FileAssetManager.entities.platforms filter (_.name.equals(p))).headOption
    } yield Target(ad, pd)
}
