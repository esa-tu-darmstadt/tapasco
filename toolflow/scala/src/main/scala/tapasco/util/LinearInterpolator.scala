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
/**
 * @file    LinearInterpolator.scala
 * @brief   Generic linear interpolation between abstract values.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util

/** LinearInterpolator is the abstract base class for linear interpolations of arbitrary
 *  types. It defines a regular interpolation in from a data set and an interpolation
 *  function on its base types A and B.
 *  @tparam A function co-domain, i.e., the ordering.
 *  @tparam B function domain, i.e., the interpolated values.
 */
abstract class LinearInterpolator[A <% Ordered[A], B](data: Seq[(A, B)])(implicit oa: Ordering[A]) extends Function[A, B] {
  private lazy val min = data map (_._1) min
  private lazy val max = data map (_._1) max
  private lazy val dmp = data.toMap[A, B]

  /** Computes the interpolated value for a. */
  def apply(a: A): B = a match {
    case v if v <= min => dmp(min)
    case v if v >= max => dmp(max)
    case v => findPos(a) match {
      case (ll, lr) if ll equals lr => dmp(lr)
      case (ll, lr) => interpolate(a, (ll, dmp(ll)), (lr, dmp(lr)))
    }
  }


  /** Abstract function to interpolate between two values. */
  protected def interpolate(a: A, left: (A, B), right: (A, B)): B

  /** Find the tuple of data elements in between which the given position lies.
   *  Corner handling: repeat last value as constant.
   */
  private def findPos(a: A, as: Seq[A] = (data map (_._1)).toSeq.sorted): (A, A) = as match {
    case ll +: lr +: ls if lr <= a => findPos(a, as.tail)
    case ll +: lr +: ls if ll <= a && lr >= a => (ll, lr)
    case lr +: Seq() => (lr, lr)
    case _ => throw new Exception("invalid data set: data")
  }
}
