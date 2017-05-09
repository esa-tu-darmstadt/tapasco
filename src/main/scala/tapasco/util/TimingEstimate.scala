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
 * @file     TimingEstimate.scala
 * @brief    Model of FPGA timing estimate.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.e)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util

final case class TimingEstimate (clockPeriod: Double, targetPeriod: Double) extends Ordered[TimingEstimate] {
  import scala.math.Ordered.orderingToOrdered
  def hasMetTiming: Boolean = clockPeriod <= targetPeriod
  def compare(that: TimingEstimate): Int =
    (this.clockPeriod, this.targetPeriod) compare (that.clockPeriod, that.targetPeriod)
}
