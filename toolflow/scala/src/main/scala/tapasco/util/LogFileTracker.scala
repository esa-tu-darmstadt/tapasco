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

/**
 * Helper methods for tracking log files.
 * Contains methods to facilitate slf4j setup to redirect logging to files.
 **/
object LogFileTracker {
  import ch.qos.logback.classic.LoggerContext
  import ch.qos.logback.classic.encoder.PatternLayoutEncoder
  import ch.qos.logback.classic.spi.ILoggingEvent
  import ch.qos.logback.core.FileAppender
  import ch.qos.logback.core.filter.Filter
  import org.slf4j.LoggerFactory
  import tapasco.Logging

  private[this] val _logger = tapasco.Logging.logger(getClass)

  /** Implements log event filtering on thread name basis. **/
  private final class ThreadFilter(threadName: String) extends Filter[ILoggingEvent] {
    import ch.qos.logback.core.spi.FilterReply

    def decide(e: ILoggingEvent): FilterReply = if(e.getThreadName().equals(threadName)) {
      FilterReply.ACCEPT
    } else {
      FilterReply.DENY
    }
  }

  /**
   * Setup a new logfile that is filled by a custom appender, logging only log
   * events which occur on the calling thread.
   * Useful for redirecting logging events on multiple threads to different files.
   * @param file Path to the file to log to (will be created, if not existing).
   * @return FileAppender instance that logs to the file.
   **/
  def setupLogFileAppender(file: String): FileAppender[ILoggingEvent] = {
    val logFileAppender: FileAppender[ILoggingEvent] = new FileAppender()
    val ctx = LoggerFactory.getILoggerFactory().asInstanceOf[LoggerContext]
    val ple = new PatternLayoutEncoder()

    ple.setPattern("[%d{HH:mm:ss} <%thread: %c{0}> %level] %msg%n")
    ple.setContext(ctx)
    ple.start()
    logFileAppender.setFile(file)
    logFileAppender.setAppend(false)
    logFileAppender.setEncoder(ple)
    logFileAppender.setContext(ctx)

    val filter = new ch.qos.logback.classic.filter.ThresholdFilter
    filter.setLevel("TRACE")
    filter.start()
    logFileAppender.addFilter(filter)

    _logger.trace("current thread name: {}", Thread.currentThread.getName())
    val filter2 = new ThreadFilter(Thread.currentThread.getName())
    filter2.start()
    logFileAppender.addFilter(filter2)
    logFileAppender.start()

    Logging.rootLogger.addAppender(logFileAppender)
    logFileAppender
  }

  /**
   * Stops the given log file appender.
   * @param appender Appender to stop, acquired via [[setupLogFileAppender]].
   **/
  def stopLogFileAppender(appender: FileAppender[ILoggingEvent]): Unit = {
    Logging.rootLogger.detachAppender(appender)
    appender.stop()
  }
}
