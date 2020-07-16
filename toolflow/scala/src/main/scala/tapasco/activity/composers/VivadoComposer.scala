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
/**
  * @file VivadoComposer.scala
  * @brief Composer implementation for Vivado Design Suite.
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.activity.composers

import java.nio.file._

import tapasco.Common
import tapasco.activity.composers.ComposeResult._
import tapasco.base._
import tapasco.base.json._
import tapasco.base.tcl._
import tapasco.dse.Heuristics
import tapasco.filemgmt.{FileAssetManager, LogTrackingFileWatcher, ProgressTrackingFileWatcher}
import tapasco.reports._
import tapasco.util.LogFormatter._
import tapasco.util._

import scala.sys.process.{Process, ProcessLogger}
import scala.util.Properties.{lineSeparator => NL}

/** Implementation of [[Composer]] for Vivado Design Suite. */
class VivadoComposer()(implicit cfg: Configuration) extends Composer {

  import VivadoComposer._

  private[this] val logger = tapasco.Logging.logger(this.getClass)

  /** @inheritdoc*/
  def maxMemoryUsagePerProcess: Int = VIVADO_PROCESS_PEAK_MEM

  /** @inheritdoc*/
  def compose(bd: Composition, target: Target, f: Heuristics.Frequency = 0, effortLevel: String,
              features: Seq[Feature] = Seq(), skipSynth: Boolean) (implicit cfg: Configuration): Composer.Result = {
    logger.debug("VivadoComposer uses at most {} threads", cfg.maxThreads getOrElse "unlimited")
    // create output struct
    val frequency = checkFrequency(f, target.pd)
    val files = VivadoComposer.Files(bd, target, frequency, features)
    // create log tracker
    val lt = new LogTrackingFileWatcher(Some(logger))
    // create output directory
    java.nio.file.Files.createDirectories(files.outdir)
    // dump configuration
    Configuration.to(cfg, files.outdir.resolve("config.json"))
    // create Tcl script
    mkTclScript(fromTemplate = Common.commonDir.resolve("design.master.tcl.template"),
      to = files.tclFile,
      projectName = Composer.mkProjectName(bd, target, frequency),
      header = makeHeader(bd, target, frequency, features),
      target = target,
      composition = composition(bd, target),
      effort = effortLevel,
      skipSynth = skipSynth)

    logger.info("Vivado starting run {}: show progress with `vivado_progress {}`", files.runName: Any, files.logFile)
    files.logFile.toFile.delete
    cfg.verbose foreach { mode =>
      logger.info("verbose mode {} is active, starting to watch {}", mode: Any, files.logFile)
      lt += files.logFile
    }
    val pt = new ProgressTrackingFileWatcher(Some(logger))
    pt += files.logFile

    // Delete outdated timing report to make sure we detect failure correctly.
    files.timFile.toFile.delete

    // Vivado shell command
    val vivadoCmd = Seq("vivado", "-mode", "batch", "-source", files.tclFile.toString,
      "-notrace", "-nojournal", "-log", files.logFile.toString)
    logger.debug("Vivado shell command: {}", vivadoCmd mkString " ")

    // execute Vivado (max runtime defined by platform, defaults to 24 hours)
    val r = InterruptibleProcess(Process(vivadoCmd, files.outdir.toFile),
      waitMillis = Some(target.pd.implTimeout.getOrElse(24) * 60 * 60 * 1000)).!(ProcessLogger(
      stdoutString => logger.trace("Vivado: {}", stdoutString),
      stderrString => logger.trace("Vivado ERR: {}", stderrString)
    ))

    lt.closeAll()
    pt.closeWithReturnCode(r)

    // check retcode
    if (r == InterruptibleProcess.TIMEOUT_RETCODE) {
      logger.error("Vivado timeout for %s in '%s'".format(files.runName, files.outdir))
      Composer.Result(Timeout, log = files.log, util = None, timing = None)
    } else if (r != 0) {
      if(files.tim.isDefined) {
        logger.warn("Bitstream might be unusable: A timing report was produced but Vivado finished with non-zero exit code %d for %s in '%s'"
          .format(r, files.runName, files.outdir))
        Composer.Result(checkTimingFailure(files), Some(files.bitFile.toString),
          files.log, files.util, files.tim)
      } else {
        logger.error("Vivado finished with non-zero exit code: %d for %s in '%s'"
          .format(r, files.runName, files.outdir))
        Composer.Result(files.log map (_.result(true)) getOrElse OtherError, log = files.log,
          util = None, timing = None)
      }
    } else {
      if (skipSynth) {
        logger.info("Skipped synthesis and bitstream generation.")
        Composer.Result(Success)
      } else if (files.tim.isEmpty) {
        throw new Exception("could not parse timing report: '%s'".format(files.timFile.toString))
      } else {
        Composer.Result(checkTimingFailure(files), Some(files.bitFile.toString),
          files.log, files.util, files.tim)
      }
    }
  }

  /** @inheritdoc*/
  def clean(bd: Composition, target: Target, f: Double = 0)(implicit cfg: Configuration): Unit = {
    cfg.outputDir(bd, target, f).resolve("microarch").toFile.deleteOnExit
    cfg.outputDir(bd, target, f).resolve("user_ip").toFile.deleteOnExit
    Common.getFiles(cfg.outputDir(bd, target, f).resolve("microarch").toFile).filter(_.isFile).map(_.delete)
    Common.getFiles(cfg.outputDir(bd, target, f).resolve("microarch").toFile).filter(_.isDirectory).foreach(_.deleteOnExit)
    Common.getFiles(cfg.outputDir(bd, target, f).resolve("user_ip").toFile).filter(_.isFile).map(_.delete)
    Common.getFiles(cfg.outputDir(bd, target, f).resolve("user_ip").toFile).filter(_.isDirectory).foreach(_.deleteOnExit)
  }

  /** @inheritdoc*/
  def cleanAll(bd: Composition, target: Target, f: Double = 0)(implicit cfg: Configuration): Unit = {
    Common.getFiles(cfg.outputDir(bd, target, f).toFile).filter(_.isFile).map(_.delete)
    Common.getFiles(cfg.outputDir(bd, target, f).toFile).filter(_.isDirectory).foreach(_.deleteOnExit)
  }

  /**
    * Ensures that the given frequency is viable for the given Platform by potentially reducing it to the maximum of
    * the Platform if it is exceeded.
    *
    * @param f        Frequency
    * @param platform Platform
    * @return resulting Frequency
    */
  private def checkFrequency(f: Heuristics.Frequency, platform: Platform): Heuristics.Frequency = {
    if (f > platform.maxFrequency) {
      logger.warn("Design Frequency exceeded the maximum and was reduced to %sMHz.".format(platform.maxFrequency))
      platform.maxFrequency
    } else {
      f
    }
  }

  /** Check for timing failure in report. */
  private def checkTimingFailure(files: Files): ComposeResult = {
    val wns = files.tim map (_.worstNegativeSlack) getOrElse Double.NegativeInfinity
    val wpws = files.tim map (_.worstPulseWidthSlack) getOrElse Double.NegativeInfinity
    if (wns < SLACK_THRESHOLD || wpws < 0.0) {
      logger.error("Vivado finished, but did not achieve timing closure for %s, WNS: %1.3f, WPWS: %1.3f, max delay path: %s in '%s'"
        .format(files.runName, wns, wpws, files.tim.map(_.maxDelayPath), files.outdir))
      TimingFailure
    } else if (wns < 0 && wns >= SLACK_THRESHOLD) {
      logger.warn("Bitstream might be unusable: Vivado finished, but did not achieve timing closure for %s, WNS: %1.3f, WPWS: %1.3f, max delay path: %s in '%s'"
        .format(files.runName, wns, wpws, files.tim.map(_.maxDelayPath), files.outdir))
        Success
    } else {
      logger.info("Vivado finished successfully for %s, WNS: %1.3f, resulting file is here: '%s'"
        .format(files.runName, wns, files.bitFile))
      Success
    }
  }

  /** Writes the .tcl script for Vivado. */
  private def mkTclScript(fromTemplate: Path, to: Path, projectName: String, header: String, target: Target,
                          composition: String, effort: String, skipSynth: Boolean): Unit = {
    // needles for template
    val needles: scala.collection.mutable.Map[String, String] = scala.collection.mutable.Map(
      "PROJECT_NAME" -> "microarch",
      "BITSTREAM_NAME" -> projectName,
      "HEADER" -> header,
      "PRELOAD_FILES" -> "",
      "PART" -> target.pd.part,
      "BOARD_PART" -> (target.pd.boardPart getOrElse ""),
      "BOARD_PART_REPOSITORY" -> (target.pd.boardPartRepository getOrElse ""),
      "BOARD_PRESET" -> (target.pd.boardPreset getOrElse ""),
      "PLATFORM_TCL" -> target.pd.tclLibrary.toString,
      "ARCHITECTURE_TCL" -> target.ad.tclLibrary.toString,
      "COMPOSITION" -> composition,
      "EFFORT_LEVEL" -> effort.toUpperCase,
      "SKIP_SYNTH" -> (if (skipSynth) "true" else "false")
    )

    // write Tcl script
    Template.interpolateFile(
      Template.DEFAULT_NEEDLE,
      fromTemplate.toString,
      to.toString,
      needles)
  }

  /** Produces the Tcl dictionary for the given composition and the IP catalog setup code for Vivado. **/
  private def composition(bd: Composition, target: Target): String = {
    // find all cores
    val cores = (for {
      ce <- bd.composition
    } yield ce.kernel -> FileAssetManager.entities.core(ce.kernel, target)).toMap
    // check that all cores are found, else abort
    if (cores.values map (_.isEmpty) reduce (_ || _)) {
      throw new Exception("could not find all required cores for target %s, missing: %s"
        .format(target, (cores filter (_._2.isEmpty)).keys mkString ", "))
    }

    val elems = for {
      ce <- bd.composition
      cd <- cores(ce.kernel)
      vl = VLNV.fromZip(cd.zipPath)
    } yield (ce.kernel, ce.count, cd, cd.zipPath, vl)

    val repoPaths =
      "set_property IP_REPO_PATHS \"[pwd]/user_ip " + Common.commonDir + "\" [current_project]" + NL +
        "file delete -force [pwd]/user_ip" + NL +
        "file mkdir [pwd]/user_ip" + NL +
        "update_ip_catalog" + NL +
        elems.map(_._4.toString).map(zp => "update_ip_catalog -add_ip " + zp + " -repo_path ./user_ip").mkString(NL) + NL +
        "update_ip_catalog" + NL

    repoPaths + (for (i <- 0 until elems.length) yield
      List(
        "dict set kernels {" + i + "} vlnv {" + elems(i)._5 + "}",
        "dict set kernels {" + i + "} count {" + elems(i)._2 + "}",
        "dict set kernels {" + i + "} id {" + elems(i)._3.id + "}",
        ""
      ).mkString(NL)).mkString(NL)
  }

  /** Produces the header section of the main Tcl file, containing several global vars. **/
  private def makeHeader(bd: Composition, target: Target, f: Heuristics.Frequency, features: Seq[Feature]): String =
    "set tapasco_freq %3.0f%s".format(f, NL) +
      (target.pd.hostFrequency map (f => "set tapasco_host_freq %3.0f%s".format(f, NL)) getOrElse "") +
      (target.pd.memFrequency map (f => "set tapasco_mem_freq %3.0f%s".format(f, NL)) getOrElse "") +
      (target.pd.boardPreset map (bp => "set tapasco_board_preset %s%s".format(bp, NL)) getOrElse "") +
      (cfg.maxThreads map (mt => "set tapasco_jobs %d%s".format(mt, NL)) getOrElse "") +
      (cfg.maxThreads map (mt => "set_param general.maxThreads %d%s".format(mt, NL)) getOrElse "") +
      (features.map { f => new FeatureTclPrinter().toTcl(f) } mkString NL)
}

/** Companion object of [[VivadoComposer]]. */
object VivadoComposer {
  /** peak memory requirements **/
  final val VIVADO_PROCESS_PEAK_MEM: Int = 15
  /** Slack threshold for WNS relaxation. */
  final val SLACK_THRESHOLD: Double = -0.3

  /** Output files and directories for a run. */
  private final case class Files(c: Composition, t: Target, f: Heuristics.Frequency, fs: Seq[Feature])
                                (implicit cfg: Configuration) {
    lazy val outdir: Path = cfg.outputDir(c, t, f, fs)
    lazy val logFile: Path = outdir.resolve("%s.log".format(Composer.mkProjectName(c, t, f)))
    lazy val tclFile: Path = outdir.resolve("%s.tcl".format(t.pd.name))
    lazy val bitFile: Path = logFile.resolveSibling("%s.%s".format(Composer.mkProjectName(c, t, f), t.pd.fileExtension))
    lazy val runName: String = "%s with %s[F=%1.3f]".format(logformat(c), t, f)
    lazy val timFile: Path = logFile.resolveSibling("timing.txt")
    lazy val utilFile: Path = logFile.resolveSibling("utilization.txt")
    lazy val log = ComposerLog(logFile)
    lazy val tim = TimingReport(timFile)
    lazy val util = UtilizationReport(utilFile)
  }

}
