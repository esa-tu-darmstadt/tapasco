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
package tapasco.filemgmt

import java.nio.file.Paths

import tapasco.Logging._
import tapasco.filemgmt.LogTrackingFileWatcher._
import tapasco.filemgmt.MultiFileWatcher.Events._
import tapasco.filemgmt.MultiFileWatcher._
import tapasco.util.Listener

/** A [[MultiFileWatcher]] which tracks a logfile:
  * subsequent logfiles mentioned in the log (matched via regex) are tracked recursively,
  * making it easy to follow complex outputs, e.g., from Vivado.
  *
  * @param _logger      Optional logger instance to use.
  * @param pollInterval Optional polling interval for files.
  */
class LogTrackingFileWatcher(_logger: Option[Logger] = None, pollInterval: Int = POLL_INTERVAL)
  extends MultiFileWatcher(POLL_INTERVAL) {
  private[this] final val logger = _logger getOrElse tapasco.Logging.logger(getClass)

  private lazy val listener = new Listener[Event] {
    def update(e: MultiFileWatcher.Event): Unit = e match {
      case LinesAdded(src, ls) => ls map { l =>
        logger.info(l)
        newFileRegex foreach { rx =>
          rx.findAllMatchIn(l) foreach { m =>
            Option(m.group(1)) match {
              case Some(p) if p.trim().nonEmpty =>
                addPath(Paths.get(p))
                logger.trace("adding new file: {}", p)
              case _ => {}
            }
          }
        }
      }
    }
  }

  addListener(listener)
}

private object LogTrackingFileWatcher {
  val newFileRegex = Seq(
    """(?i)output in (\S*)$""".r.unanchored,
    """(?i)\s*(\S*/synth_1/runme\.log)$""".r.unanchored,
    """(?i)\s*(\S*/impl_1/runme\.log)$""".r.unanchored)
}
