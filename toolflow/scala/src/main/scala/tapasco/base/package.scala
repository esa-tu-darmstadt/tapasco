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
package tapasco

import tapasco.base._

import scala.language.implicitConversions

/**
 * Contains the basic entities and objects of Tapasco:
 * Definitions of [[Architecture]], [[Platform]], [[Kernel]], ...,
 * can be found here. These are the basic domain entities of TPC.
 **/
package object base {
  implicit def toTarget(td: TargetDesc): Target = Target.fromString(td.a, td.p).get
  implicit def toTargetDesc(t: Target): TargetDesc = TargetDesc(t.ad.name, t.pd.name)
}
