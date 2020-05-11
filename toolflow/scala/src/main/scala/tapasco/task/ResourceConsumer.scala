/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco.task

import tapasco.slurm._

/**
  * ResourceConsumers advertise their usage of CPUs, Memory and licences.
  **/
trait ResourceConsumer {
  /** Number of CPUs this consumer will use during run (max.). */
  val cpus: Int
  /** Number of bytes of RAM this consumer will use during run (max.). */
  val memory: Int
  /** Number of licences per feature this consumer will use during run (max.). */
  val licences: Map[String, Int]

  /** Returns true, if the consumer can be started immediately. */
  def canStart: Boolean = true

  /** Create merged consumer by summing the resource requirements. */
  def +(other: ResourceConsumer): ResourceConsumer = ResourceConsumer.merge(this, other)

  /** Returns true, if this consumer uses more resources than other. */
  def usesMoreThan(other: ResourceConsumer): Boolean = if (!Slurm.enabled) {
    cpus > other.cpus ||
      (licences.keys map { k => licences(k) > other.licences.getOrElse(k, Integer.MAX_VALUE) } fold false) (_ || _)
  } else {
    (licences.keys map { k => licences(k) > other.licences.getOrElse(k, Integer.MAX_VALUE) } fold false) (_ || _)
  }

  override lazy val toString: String = "(cpus: %d, mem: %d, licences: %s)".format(cpus, memory, licences)
}

/** ResourceConsumer companion object. **/
object ResourceConsumer {
  /**
    * Create a new ResourceConsumer.
    *
    * @param ccpus    Number of CPUs this consumer will use during run (max.).
    * @param cmemory  Number of bytes of RAM this consumer will use during run (max.).
    * @param licences Number of licences per feature this consumer will use during run (max.).
    **/
  def apply(ccpus: Int, cmemory: Int, clicences: Map[String, Int]): ResourceConsumer = new ResourceConsumer {
    val cpus = ccpus
    val memory = cmemory
    val licences = clicences
  }

  private[ResourceConsumer]
  def mergeLicences(a: ResourceConsumer, b: ResourceConsumer): Map[String, Int] =
    ((a.licences.keys ++ b.licences.keys) map { k =>
      k -> (a.licences.getOrElse(k, 0) + b.licences.getOrElse(k, 0))
    }).toMap

  private[ResourceConsumer]
  def merge(a: ResourceConsumer, b: ResourceConsumer) = new ResourceConsumer {
    val cpus = a.cpus + b.cpus
    val memory = a.memory + b.memory
    val licences = mergeLicences(a, b)
  }

  /** ResourceConsumer with no resource requirements. **/
  object NullConsumer extends ResourceConsumer {
    val cpus = 0
    val memory = 0
    val licences: Map[String, Int] = Map()
  }

}

