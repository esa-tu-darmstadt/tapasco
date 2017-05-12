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
package de.tu_darmstadt.cs.esa.tapasco
import  base._
import  jobs.executors._
import  filemgmt._
import  task._
import  itapasco.controller._
import  parser._
import  slurm._
import  java.nio.file.Path

object Tapasco {
  import org.slf4j.LoggerFactory
  import ch.qos.logback.core.FileAppender
  import ch.qos.logback.classic.LoggerContext
  import ch.qos.logback.classic.encoder.PatternLayoutEncoder
  import ch.qos.logback.classic.spi.ILoggingEvent
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)
  private[this] val logFileAppender: FileAppender[ILoggingEvent] = new FileAppender()

  private def setupLogFileAppender(file: String, quiet: Boolean = false) = {
    val ctx = LoggerFactory.getILoggerFactory().asInstanceOf[LoggerContext]
    val ple = new PatternLayoutEncoder()
    ple.setPattern("[%d{HH:mm:ss} <%thread: %c{0}> %level] %msg%n")
    ple.setContext(ctx)
    ple.start()
    logFileAppender.setFile(file)
    logFileAppender.setAppend(false)
    logFileAppender.setEncoder(ple)
    logFileAppender.setContext(ctx)
    logFileAppender.start()
    val filter = new ch.qos.logback.classic.filter.ThresholdFilter
    filter.setLevel("INFO")
    logFileAppender.addFilter(filter)
    Logging.rootLogger.addAppender(logFileAppender)
    if (quiet) Logging.rootLogger.setAdditive(quiet)
  }

  private def runGui(args: Array[String])(implicit cfg: Configuration): Boolean = args.headOption map { firstArg =>
    (firstArg.toLowerCase equals "itapasco") && { new AppController(Some(cfg)).show; true }
  } getOrElse false

  def main(args: Array[String]) {
    implicit val tasks = new Tasks
    val ok = try {
      // try to parse all arguments
      val c = CommandLineParser(args mkString " ") match {
        // if that fails, check if special command was given as first parameter
        case Left(ex) => CommandLineParser(args.tail mkString " ")
        case r => r
      }
      if (c.isRight) {
        // get parsed Configuration
        implicit val cfg = c.right.get
        FileAssetManager(cfg)
        if (cfg.slurm) Slurm.enabled = cfg.slurm
        FileAssetManager.start()
        cfg.logFile map { logfile: Path => setupLogFileAppender(logfile.toString) }
        logger.info(cfg.toString)
        runGui(args) || (cfg.jobs map { execute(_) } fold true) (_ && _)
      } else {
        logger.error("invalid arguments: {}", c.left.get.toString)
        logger.error(Usage())
        false
      }
    } catch { case ex: Exception =>
      logger.error(ex.toString)
      logger.error("Stack trace: {}", ex.getStackTrace() map (_.toString) mkString "\n")
      false
    } finally {
      FileAssetManager.stop()
      tasks.stop()
    }
    logger.debug("active threads: {}", Thread.activeCount())
    if (Thread.activeCount() > 0) {
      import scala.collection.JavaConverters._
      val m = Thread.getAllStackTraces().asScala
      m.values foreach { strace => logger.debug(strace mkString scala.util.Properties.lineSeparator) }
    }
    if (! ok) {
      logger.error("TPC finished with errors")
      sys.exit(1)
    } else {
      logger.info("TPC finished successfully")
    }
  }
}
