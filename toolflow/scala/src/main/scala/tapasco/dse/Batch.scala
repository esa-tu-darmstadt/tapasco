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
package tapasco.dse

import java.util.concurrent.CountDownLatch

import tapasco.activity.composers._
import tapasco.base.Configuration

sealed private trait Batch extends Startable {
  def id: Int

  def runs: Seq[Run]

  def isFirstSuccess: Boolean

  def result: Option[Run]
}

private class ConcreteBatch(val id: Int, val runs: Seq[Run])
                           (implicit exploration: Exploration, configuration: Configuration) extends Batch {
  assert(runs.length > 0, "at least one run must be given per batch")
  private[this] val _logger = tapasco.Logging.logger(getClass)

  def isFirstSuccess: Boolean = runs(0).result map (_.result.equals(ComposeResult.Success)) getOrElse false

  def result: Option[Run] = runs.find(r => r.result map (_.result.equals(ComposeResult.Success)) getOrElse false)

  def start(signal: Option[CountDownLatch] = None): Unit = {
    val done: CountDownLatch = new CountDownLatch(runs.length)
    val elems = runs map (_.element)
    exploration.publish(Exploration.Events.BatchStarted(id, elems))
    _logger.trace("batch {}: starting runs ...", id)
    runs foreach { r =>
      _logger.info("starting [%s] [F=%2.3f] for %s".format(r.element.composition, r.element.frequency, r.target))
      r.start(done)
    }
    _logger.trace("batch {}: awaiting result ...", id)
    done.await()
    _logger.trace("batch {}: finished: result = {}", id, result.toString)
    exploration.publish(Exploration.Events.BatchFinished(id, elems, runs flatMap (_.result)))
    signal foreach (_.countDown())
  }
}

