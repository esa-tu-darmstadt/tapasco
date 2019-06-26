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

import java.io.{BufferedReader, FileReader}
import java.nio.file.Path
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicReference

import tapasco.util._

import scala.collection.JavaConverters._
import scala.collection.mutable.{ArrayBuffer, Map}

/**
  * MultiFileWatcher monitors the contents of multiple files at once.
  * Content is polled regularly (pollInterval), changes in the content are
  * published as Events (using the [[util.Publisher]] methods).
  *
  * @param pollInterval Polling interval in ms (default: [[MultiFileWatcher.POLL_INTERVAL]]).
  **/
class MultiFileWatcher(pollInterval: Int = MultiFileWatcher.POLL_INTERVAL) extends Publisher {
  type Event = MultiFileWatcher.Event

  import MultiFileWatcher.Events._

  /**
    * Add a file to the monitoring.
    *
    * @param p Path to file to be monitored.
    */
  def +=(p: Path) {
    _waitingFor.synchronized {
      _waitingFor += p
    }; open(p)
  }

  @inline def addPath(p: Path) {
    this += p
  }

  /**
    * Add a collection of files to the monitoring.
    *
    * @param ps Collection of Paths to files to be monitored.
    */
  def ++=(ps: Traversable[Path]) {
    ps foreach (this += _)
  }

  @inline def addPaths(ps: Traversable[Path]) {
    this ++= ps
  }

  /**
    * Remove a file from the monitoring.
    *
    * @param p Path to file to be removed.
    */
  def -=(p: Path) {
    close(p)
  }

  @inline def remPath(p: Path) {
    this -= p
  }

  /**
    * Remove a collection of files from the monitoring.
    *
    * @param ps Collection of Paths to files to be removed.
    */
  def --=(ps: Traversable[Path]): Unit = ps foreach (close _)

  @inline def remPaths(ps: Traversable[Path]) {
    this --= ps
  }

  /** Remove and close all files. */
  def closeAll(): Unit = {
    _watchThread.set(None)
    _files.synchronized {
      _files.clear
    }
    _waitingFor.synchronized {
      _waitingFor.clear
    }
  }

  private[this] var _waitingFor: ArrayBuffer[Path] = ArrayBuffer()

  private def open(p: Path): Boolean = {
    val res = try {
      _files.synchronized {
        _files += p -> new BufferedReader(new FileReader(p.toString))
      }
      logger.trace("opened {} successfully", p.toString)
      true
    } catch {
      case ex: java.io.IOException =>
        logger.trace("could not open {}, will retry ({})", p: Any, ex: Any)
        false
    }
    startWatchThread
    res
  }

  private def close(p: Path): Unit = {
    _files.synchronized {
      _files -= p
    }
    _waitingFor.synchronized {
      _waitingFor -= p
    }
  }

  @scala.annotation.tailrec
  private def readFrom(br: BufferedReader, ls: Seq[String] = Seq()): Seq[String] = {
    val line = scala.util.Try(Option(br.readLine())).toOption.flatten
    if (line.isEmpty) ls else readFrom(br, ls :+ line.get)
  }

  private def startWatchThread: Unit = {
    logger.trace("starting file watch thread ...")
    if (_watchThread.compareAndSet(None, Some(new Thread(new Runnable {
      def run() {
        try {
          var lastWasEmpty = false
          while (!_files.isEmpty || !_waitingFor.isEmpty || !lastWasEmpty) {
            val waits = _waitingFor.synchronized {
              _waitingFor.toList
            }
            val files = _files.synchronized {
              _files.toMap
            }
            Thread.sleep(pollInterval)
            waits foreach { p =>
              logger.trace("waiting for {}", p)
              if (open(p)) _waitingFor.synchronized {
                _waitingFor -= p
              }
            }
            val all_files = files ++ _files.synchronized {
              _files.toMap
            }
            logger.trace("reading from files: {}", all_files)
            all_files foreach { case (p, br) =>
              val lines = readFrom(br)
              if (lines.length > 0) {
                logger.trace("read {} lines from {}", lines.length, p)
                publish(LinesAdded(p, lines))
              }
            }
            lastWasEmpty = all_files.isEmpty
          }
          _watchThread.set(None)
        } catch {
          case e: InterruptedException => _watchThread.set(None)
        }
      }
    })))) {
      _watchThread.get map (_.start)
      Thread.sleep(100)
    }
  }

  private[this] var _watchThread: AtomicReference[Option[Thread]] = new AtomicReference(None)
  private[this] val _files: Map[Path, BufferedReader] = new ConcurrentHashMap().asScala
  private[this] val logger = tapasco.Logging.logger(getClass)
}

/** MultiFileWatcher companion object. */
object MultiFileWatcher {

  sealed trait Event

  object Events {

    /** Lines ls have been added to file at src. **/
    final case class LinesAdded(src: Path, ls: Traversable[String]) extends Event

  }

  /** Default polling interval for files: once every 2 seconds. **/
  final val POLL_INTERVAL = 2000 // 2sec
}
