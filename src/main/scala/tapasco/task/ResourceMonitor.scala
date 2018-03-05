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
package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.util.{MemInfo, FlexLicenceManagerStatus}

/**
 * ResourceMonitors manage a fixed pool of resources and consumers working with
 * these resources. A task scheduler can use the ResourceMonitor to provide a
 * safe scheduling of resource-sensitive tasks.
 **/
trait ResourceMonitor {
  def canStart(t: ResourceConsumer): Boolean
  def doStart(t: ResourceConsumer): Unit
  def didFinish(t: ResourceConsumer): Unit
  def status: String
}


/**
 * Default implementation of a ResourceMonitor:
 * Monitors CPUs, memory and licences.
 **/
private class DefaultResourceMonitor extends ResourceMonitor {
  import scala.collection.mutable.Set
  private[this] val _cpus = Runtime.getRuntime().availableProcessors()
  private[this] val _mem  = MemInfo.totalMemory
  private[this] val _cons = Set[ResourceConsumer]()
  private val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private[this] val _available = new ResourceConsumer {
    val cpus = _cpus
    val memory = _mem
    val licences = FlexLicenceManagerStatus.licences map (c => (c._1, c._2._1))
  }

  private def current = (_cons fold ResourceConsumer.NullConsumer) (_ + _)
  private def check(cons: Set[ResourceConsumer]) = {
    logger.trace("checking: {}, available: {}", (cons fold ResourceConsumer.NullConsumer) (_ + _): Any, _available)
    ! ((cons fold ResourceConsumer.NullConsumer) (_ + _) usesMoreThan _available)
  }

  def doStart(t: ResourceConsumer): Unit     = if (canStart(t)) _cons.synchronized { _cons += t }
  def didFinish(t: ResourceConsumer): Unit   = _cons.synchronized { _cons -= t }
  def canStart(t: ResourceConsumer): Boolean = Slurm.enabled || (t.canStart && check(_cons + t))
  def status: String = "%d active consumers, %d/%d CPUs, %1.1f/%1.1f GiB RAM, %d total licences in use".format(
    _cons.size, current.cpus, _cpus,
    current.memory / 1024.0 / 1024.0,
    _mem / 1024.0 / 1024.0,
    (current.licences.values fold 0) (_ + _)
  )
}

/** ResourceMonitor companion object. **/
object ResourceMonitor {
  /** Obtain a new ResourceMonitor. **/
  def apply(): ResourceMonitor = new DefaultResourceMonitor()
}

