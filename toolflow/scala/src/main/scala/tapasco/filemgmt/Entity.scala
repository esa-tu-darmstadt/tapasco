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
package tapasco.filemgmt

/**
 * Base class of entities in the TPC flow:
 * Covers all objects which are defined dynamically by description files,
 * e.g., Platforms, Architectures, Kernels.
 **/
sealed trait Entity

/** Singleton object containing all [[Entity]] instances. **/
final object Entities {
  final case object Architectures extends Entity
  final case object Cores         extends Entity
  final case object Compositions  extends Entity
  final case object Kernels       extends Entity
  final case object Platforms     extends Entity

  def apply(): Seq[Entity] = Seq(Architectures, Cores, Compositions, Kernels, Platforms)
}

