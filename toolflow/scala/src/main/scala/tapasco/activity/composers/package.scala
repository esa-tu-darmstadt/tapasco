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
package tapasco.activity

/** Composers subpackage: Contains Composer activities.
  * A Composer produces a complete hardware-design from a [[tapasco.base.Composition]],
  * i.e., a set of [[tapasco.base.Kernel]] instances and instantiation counts.
  * To this end, a Composer has to construct a full micro-architecture by
  * instantiating the Kernels (each instance is called a processing
  * element, PE) and connecting them to the host and memory.
  * Currently only Vivado Design Suite is supported as a Composer.
  * */
package object composers
