package de.tu_darmstadt.cs.esa.tapasco.itapasco.common

/**
 * Helper methods for tracking log files.
 * Contains methods to facilitate slf4j setup to redirect logging to files.
 **/
object LogFileTracker {
  import org.slf4j.LoggerFactory
  import ch.qos.logback.core.FileAppender
  import ch.qos.logback.core.filter.Filter
  import ch.qos.logback.classic.LoggerContext
  import ch.qos.logback.classic.encoder.PatternLayoutEncoder
  import ch.qos.logback.classic.spi.ILoggingEvent
  import de.tu_darmstadt.cs.esa.tapasco.Logging
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

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
