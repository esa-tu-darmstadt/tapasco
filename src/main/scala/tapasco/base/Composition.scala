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
 * @file    Composition.scala
 * @brief   Model: TPC Composition.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  java.nio.file._
import  builder._

case class Composition (
      descPath: Path,
      description: Option[String],
      composition: Seq[Composition.Entry]
    ) extends Description (descPath) {
  def id: String =
    if ("N/A" == descPath.toString) {
      "0x" + composition.map(_.toString).mkString("|").hashCode.toHexString
    } else {
      descPath.getFileName.toString
    }
  override lazy val toString: String =
    "[%s]".format(composition map { ce => "%s x %d".format(ce.kernel, ce.count) } mkString ", ")

  /** Adds instances of a given kernel to the Composition. If the kernel already exists, its
    * count is increased, otherwise it is appended.
    * @param e [[Composition.Entry]] with the name and number of instances of the Kernel to add.
    **/
  def +(e: Composition.Entry): Composition = if (composition map (_.kernel) contains e.kernel) {
    // find existing entry and add the count
    this.copy(composition = this.composition map { _ match {
      case old: Composition.Entry if old.kernel.equals(e.kernel) => Composition.Entry(e.kernel, old.count + e.count)
      case e => e
    }})
  } else {
    // just append
    ::(e)
  }

  /** Removes the given number of instances of the kernel from the Composition. If there are
    * now 0 or less instances, the entry will be removed.
    * @param e [[Composition.Entry]] with the name and number of instances of the Kernel to be removed.
    */
  def -(e: Composition.Entry): Composition = this.copy(composition = this.composition map { _ match {
    case old: Composition.Entry if old.kernel.equals(e.kernel) => Composition.Entry(e.kernel, old.count - e.count)
    case e => e
  }} filter (_.count <= 0))

  /** Appends the given [[Composition.Entry]] to the Composition. */
  def ::(e: Composition.Entry): Composition = this.copy(composition = this.composition :+ e)

  /** Sets the given composition entry, replacing all previous ones for the same kernel. */
  def set(e: Composition.Entry): Composition = if (e.count > 0) {
    if (this(e.kernel) == 0) {
      ::(e)
    } else {
      this.copy(composition = this.composition collect {
        case ce: Composition.Entry if ce.kernel.equals(e.kernel) => e
        case ce => ce
      })
    }
  } else {
    this.copy(composition = this.composition filterNot (_.kernel.equals(e.kernel)))
  }

  /** Returns true, iff the composition does not contain any instances. */
  def isEmpty: Boolean  = composition.isEmpty
  /** Returns true, iff the composition contains at least one instance of a Kernel. */
  def nonEmpty: Boolean = composition.nonEmpty

  /** Returns the number of instances of the kernel with the given name.
    * @param name Name of the kernel (case-sensitive).
    * @return Number of instances in the composition.
    */
  def apply(name: String): Int = count(name)

  /** Returns the number of instances of the kernel with the given name.
    * @param name Name of the kernel (case-sensitive).
    * @return Number of instances in the composition.
    */
  def count(name: String): Int = (composition collect {
    case ce: Composition.Entry if ce.kernel.equals(name) => ce.count
  } fold 0) (_ + _)
}

object Composition extends Builds[Composition] {
  final case class Entry(kernel: String, count: Int)
}
