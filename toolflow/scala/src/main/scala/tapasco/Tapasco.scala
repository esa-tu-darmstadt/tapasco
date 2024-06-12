/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco

import java.nio.file.Path
import java.util.Locale

import tapasco.base._
import tapasco.filemgmt._
import tapasco.parser._
import tapasco.slurm._
import tapasco.task._

import scala.concurrent._

object Tapasco {

  import ch.qos.logback.classic.LoggerContext
  import ch.qos.logback.classic.encoder.PatternLayoutEncoder
  import ch.qos.logback.classic.spi.ILoggingEvent
  import ch.qos.logback.core.FileAppender
  import org.slf4j.LoggerFactory

  private[this] implicit val logger = tapasco.Logging.logger(this.getClass)
  private[this] val logFileAppender: FileAppender[ILoggingEvent] = new FileAppender()
  private[this] final val UNLIMITED_THREADS = 1000

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

  private def dryRun(p: Path)(implicit cfg: Configuration) {
    import base.json._
    logger.info("dry run, dumping configuration to {}", p)
    Configuration.to(if (cfg.jobs.isEmpty) cfg.jobs(jobs.JobExamples.jobs) else cfg, p)
    System.exit(0)
  }

  // scalastyle:off cyclomatic.complexity
  // scalastyle:off method.length
  def main(args: Array[String]) {
    Locale.setDefault(Locale.US);

    // try to parse all arguments
    val c = CommandLineParser(args mkString " ")
    logger.debug("parsed config: {}", c)
    val ok = if (c.isRight) {
      implicit val tasks = new Tasks(c.right.get.maxTasks)
      // get parsed Configuration
      implicit val cfg = c.right.get
      // dump config and exit, if dryRun is selected
      cfg.dryRun foreach (dryRun _)
      // else continue ...
      logger.trace("configuring FileAssetManager...")
      FileAssetManager(cfg)
      logger.trace("SLURM: {}", cfg.slurm)
      if (cfg.slurm.isDefined) {
        Slurm.set_cfg(cfg.slurm.get match {
          case "local" => Slurm.EnabledLocal()
          case t       => Slurm.EnabledRemote(t)
        })
      }
      FileAssetManager.start()
      logger.trace("parallel: {}", cfg.parallel)
      cfg.logFile map { logfile: Path => setupLogFileAppender(logfile.toString) }
      logger.info("Running with configuration: {}", cfg.toString)

      def get(f: Future[Boolean]): Boolean = {
        Await.ready(f, duration.Duration.Inf); f.value map (_ getOrElse false) getOrElse false
      }

      try {
        if (cfg.parallel) {
          implicit val exe = ExecutionContext.fromExecutor(new java.util.concurrent.ForkJoinPool(cfg.maxTasks getOrElse UNLIMITED_THREADS))
          (cfg.jobs map { j => Future {
            jobs.executors.execute(j)
          }
          } map (get _) fold true) (_ && _)
        } else {
          (cfg.jobs map {
            jobs.executors.execute(_)
          } fold true) (_ && _)
        }
      } catch {
        case ex: Exception =>
          logger.error(ex.toString)
          logger.error("Stack trace: {}", ex.getStackTrace() map (_.toString) mkString "\n")
          false
      } finally {
        FileAssetManager.stop()
        tasks.stop()
      }
    } else {
      logger.error("invalid arguments: {}", c.left.get.toString)
      logger.error("run `tapasco -h` or `tapasco --help` to get more info")
      false
    }

    logger.debug("active threads: {}", Thread.activeCount())
    if (Thread.activeCount() > 0) {
      import scala.collection.JavaConverters._
      val m = Thread.getAllStackTraces().asScala
      m.values foreach { strace => logger.debug(strace mkString scala.util.Properties.lineSeparator) }
    }

    if (!ok) {
      logger.error("TaPaSCo finished with errors")
      sys.exit(1)
    } else {
      logger.info("TaPaSCo finished successfully")
    }
  }

  // scalastyle:on method.length
  // scalastyle:on cyclomatic.complexity
}
