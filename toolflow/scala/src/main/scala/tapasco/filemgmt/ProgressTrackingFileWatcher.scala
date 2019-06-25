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
package tapasco.filemgmt

import tapasco.Logging._
import tapasco.filemgmt.MultiFileWatcher.Events._
import tapasco.filemgmt.MultiFileWatcher._
import tapasco.filemgmt.ProgressTrackingFileWatcher._
import tapasco.util.Listener

import scala.concurrent.duration.Duration

/**
  * A [[MultiFileWatcher]] which tracks the overall logfile.
  * Using a FSM, the current state of the Compose Progression is Determined and Logged
  * to give the user an overview how far the compose-Task has progressed.
  * @param _logger Optional logger instance to use.
  * @param pollInterval Polling interval in ms (default: [[MultiFileWatcher.POLL_INTERVAL]]).
  */
class ProgressTrackingFileWatcher(_logger: Option[Logger] = None, pollInterval: Int = POLL_INTERVAL)
  extends MultiFileWatcher(POLL_INTERVAL) {
  private[this] final val logger = _logger getOrElse tapasco.Logging.logger(getClass)

  var currentState: Int = -1
  val start: Long = System.currentTimeMillis()
  var stageStart: Long = System.currentTimeMillis()
  var lastLog: Long = 0

  private lazy val listener = new Listener[Event] {
    def update(e: MultiFileWatcher.Event): Unit = e match {
      case LinesAdded(src, ls) => {
        ls foreach {l =>
          checkState(l)
        }
      }
    }
  }

  /**
    * Checks whether a transition has occured depending on the current line of the log.
    * If so, the corresponding new state is logged.
    * Additionally, the finished State is also logged with its runtime.
    * @param string parsed String
    */
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
      if(old != -1) {
        val oldProgressionString = progressionStringsInfo(old)._2
        logger.info("Finished %s after %s (Total Elapsed: %s)".format(oldProgressionString, timeString(stageStart), timeString(start)))
      }
      val progressionString = progressionStringsInfo(currentState)._2
      logger.info("Started %s (Total Elapsed: %s)".format(progressionString, timeString(start)))
      stageStart = System.currentTimeMillis()
    }
  }

  /**
    * Calculates the time since a certain TimeStamp and transforms it into a hh:mm:ss-Formatted String.
    * @param since timestamp
    * @return TimeString
    */
  private def timeString(since: Long): String = {
    val now = System.currentTimeMillis()
    val dur = Duration(now-since, "millis")
    f"${dur.toHours}%d:${dur.toMinutes % 60}%02d:${dur.toSeconds % 60}%02d"
  }

  /**
    * Closes all Files watched by this Watcher and give a corresponding result message based on the return code.
    * @param returnCode return code
    */
  def closeWithReturnCode(returnCode: Int): Unit = {
    if(returnCode == 0) {
      logger.info("Finished %s after %s (Total Elapsed: %s)".format(progressionStringsInfo(currentState)._2, timeString(stageStart), timeString(start)))
      super.closeAll()
    } else {
      logger.error("%s failed after %s (Total Elapsed: %s)".format(progressionStringsInfo(currentState)._2, timeString(stageStart), timeString(start)))
      super.closeAll()
    }
  }

  addListener(listener)
}

private object ProgressTrackingFileWatcher {
  val progressionStringsInfo = Seq(
    ("create_comp", "System Composition"),
    ("synth_design", "Synthesis"),
    ("place_design", "Placing"),
    ("route_design", "Routing"),
    ("write_bitstream", "Writing Bitstream")
  )


}