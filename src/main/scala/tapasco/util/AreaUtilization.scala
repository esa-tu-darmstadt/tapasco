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
 * @file     AreaUtilization.scala
 * @brief    Helper object for computing area utilization estimations.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.e)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  scala.collection.mutable.Map

/**
 * Helper object: Compute area utilization factors from [[base.Core]] and [[base.Composition]] instances.
 **/
object AreaUtilization {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _coreMemos: Map[Configuration, Memoization[(Target, Core), Option[AreaEstimate]]] = Map()
  private[this] val _compoMemos: Map[Configuration, Memoization[(Target, Composition), Option[AreaEstimate]]] = Map()

  /** Compute an area utilization estimate for the given core on the given Target. */
  def apply(target: Target, cd: Core)(implicit cfg: Configuration): Option[AreaEstimate] = _coreMemos.synchronized {
    (_coreMemos.get(cfg) getOrElse {
      val memo = new Memoization((computeCoreArea _).tupled)
      _coreMemos += cfg -> memo
      memo
    }) (target, cd)
  }

  /** Compute an area utilization estimate for the given composition on the given Target. */
  def apply(target: Target, bd: Composition)(implicit cfg: Configuration): Option[AreaEstimate] = _compoMemos.synchronized {
    (_compoMemos.get(cfg) getOrElse {
      val memo = new Memoization((computeCompositionArea _).tupled)
      _compoMemos += cfg -> memo
      memo
    }) (target, bd)
  }

  private def computeCoreArea(target: Target, cd: Core)(implicit cfg: Configuration): Option[AreaEstimate] =
    FileAssetManager.reports.synthReport(cd.name, target) flatMap (_.area)

  private def computeCompositionArea(target: Target, bd: Composition)(implicit cfg: Configuration): Option[AreaEstimate] = {
    assert (bd.composition.length > 0, "composition must not be empty")
    val counts = bd.composition map (_.count)
    val cores  = bd.composition flatMap { ce => FileAssetManager.entities.core(ce.kernel, target) }
    val areas  = cores flatMap (apply(target, _))
    // check if all required data is available
    if (cores.length < bd.composition.length) {
      _logger.warn("could not find all core base. no area estimate for composition")
      None
    } else if (areas.length < bd.composition.length) {
      _logger.warn("could not find all synthesis reports, no area estimate for composition")
      None
    } else {
      require(bd.nonEmpty, "composition must not be empty")
      _logger.trace("bd = {}", bd)
      _logger.debug("areas = {}, counts = {}", areas: Any, counts)
      Some((areas zip counts) map (a => a._1 * a._2) reduce (_ + _))
    }
  }
}
