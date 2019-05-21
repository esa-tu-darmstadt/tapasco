//
// Copyright (C) 2019 ESA, TU Darmstadt
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
package de.tu_darmstadt.cs.esa.tapasco.filemgmt

import de.tu_darmstadt.cs.esa.tapasco.Logging._
import de.tu_darmstadt.cs.esa.tapasco.util.Listener
import MultiFileWatcher._
import Events._
import ProgressTrackingFileWatcher._


class ProgressTrackingFileWatcher(_logger: Option[Logger] = None, pollInterval: Int = POLL_INTERVAL)
  extends MultiFileWatcher(POLL_INTERVAL) {
  private[this] final val logger = _logger getOrElse de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  var currentState: Int = -1

  private lazy val listener = new Listener[Event] {
    def update(e: MultiFileWatcher.Event): Unit = e match {
      case LinesAdded(src, ls) => ls foreach {l =>
        checkState(l)
      }
    }
  }

  private def checkState(string: String): Unit = {
    val old = currentState
    if(currentState == -1) {
      currentState = currentState + 1
    }
    for(i <- progressionStringsInfo.indices) {
      val progressionString = progressionStringsInfo(i)._1
      if(i == -1 || (currentState == i - 1 && string.contains(progressionString))){
        currentState = currentState + 1
      }
    }
    if(old != currentState) {
      logger.info(progressionStringsInfo(currentState)._2)
    }
  }

  addListener(listener)
}

private object ProgressTrackingFileWatcher {
  val progressionStringsInfo = Seq(
    ("create_comp", "Composing"),
    ("synth_design", "Synthesising"),
    ("place_design", "Placing"),
    ("route_design", "Routing"),
    ("write_bitstream", "Writing Bitstream")
  )


}