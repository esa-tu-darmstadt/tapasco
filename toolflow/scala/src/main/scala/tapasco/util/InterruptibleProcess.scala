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
package tapasco.util

import scala.collection.mutable.ArrayBuffer
import scala.sys.process._

private[tapasco] final case class InterruptibleProcess(p: ProcessBuilder, waitMillis: Option[Int] = None) {
  private final val logger = tapasco.Logging.logger(getClass)
  private var result: Option[Int] = None
  private val output: ArrayBuffer[String] = ArrayBuffer()
  private val errors: ArrayBuffer[String] = ArrayBuffer()
  private val plog: ProcessLogger = ProcessLogger(output += _, errors += _)

  private def mkThread(plogger: ProcessLogger) = new Thread(new Runnable {
    private var proc: Option[Process] = None

    def run() {
      try {
        proc = Some(p.run(plogger))
        result = proc map (_.exitValue())
      } catch {
        case e: InterruptedException =>
          logger.warn("thread interrupted, destroying external process")
          proc foreach {
            _.destroy()
          }
      }
    }
  })

  private def mkThread(pio: ProcessIO) = new Thread(new Runnable {
    private var proc: Option[Process] = None

    def run() {
      try {
        proc = Some(p.run(pio))
        result = proc map (_.exitValue())
      } catch {
        case e: InterruptedException =>
          logger.warn("thread interrupted, destroying external process")
          proc foreach {
            _.destroy()
          }
      }
    }
  })

  def !(plogger: ProcessLogger = plog): Int = {
    val t = mkThread(plogger)
    t.start()
    if (waitMillis.isEmpty) t.join() else t.join(waitMillis.get)
    if (t.isAlive()) t.interrupt()
    result getOrElse InterruptibleProcess.TIMEOUT_RETCODE
  }

  def !(pio: ProcessIO): Int = {
    val t = mkThread(pio)
    t.start()
    if (waitMillis.isEmpty) t.join() else t.join(waitMillis.get)
    if (t.isAlive()) t.interrupt()
    result getOrElse InterruptibleProcess.TIMEOUT_RETCODE
  }

  def !!(): String = {
    this.!()
    output mkString scala.util.Properties.lineSeparator
  }
}

object InterruptibleProcess {
  final val TIMEOUT_RETCODE = 124 // matches 'timeout' command
  // custom ProcessIO: ignore everything
  val io = new ProcessIO(
    stdin => {
      stdin.close()
    },
    stdout => {
      stdout.close()
    },
    stderr => {
      stderr.close()
    }
  )
}
