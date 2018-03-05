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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.globals
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file._

protected[itapasco] object Job extends Publisher {
  private[this] final val INITIAL_FREQUENCY = 50
  sealed trait Event
  object Events {
    final case class JobChanged(job: DesignSpaceExplorationJob) extends Event
  }

  private var _job = DesignSpaceExplorationJob(
    initialComposition = Composition(Paths.get("N/A"), None, Seq()),
    initialFrequency = INITIAL_FREQUENCY,
    dimensions = DesignSpace.Dimensions(frequency = true),
    heuristic = Heuristics.ThroughputHeuristic,
    batchSize = Runtime.getRuntime().availableProcessors(),
    basePath = None,
    _architectures = None,
    _platforms = None,
    features = None,
    debugMode = None
  )

  def job: DesignSpaceExplorationJob = _job
  def job_=(j: DesignSpaceExplorationJob): Unit = if (! j.equals(_job)) {
    _job = j
    publish(Events.JobChanged(_job))
  }
}
