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
package tapasco.activity.hls

import java.io.FileWriter
import java.nio.file._

import tapasco.Common
import tapasco.Logging._
import tapasco.base._
import tapasco.filemgmt.LogTrackingFileWatcher
import tapasco.util._

import scala.io.Source
import scala.sys.process._
import scala.util.Properties.{lineSeparator => NL}

private object VivadoHighLevelSynthesis extends HighLevelSynthesizer {

  import HighLevelSynthesizer._

  private[this] implicit final val logger =
    tapasco.Logging.logger(getClass)

  def clean(k: Kernel, target: Target)(implicit cfg: Configuration): Unit = {
    Common.getFiles(cfg.outputDir(k, target).resolve("hls").toFile) filter (_.isFile) map (_.delete)
    Common.getFiles(cfg.outputDir(k, target).resolve("hls").toFile) filter (_.isDirectory) map (_.deleteOnExit)
  }

  def cleanAll(k: Kernel, target: Target)(implicit cfg: Configuration): Unit = {
    clean(k, target)
    Common.getFiles(outputZipFile(k, target).getParent.toFile) filter (_.isFile) map (_.delete)
    Common.getFiles(outputZipFile(k, target).getParent.toFile) filter (_.isDirectory) map (_.deleteOnExit)
  }

  def synthesize(k: Kernel, t: Target)(implicit cfg: Configuration): Result = try {
    // create log tracker
    val lt = new LogTrackingFileWatcher(Some(logger))
    val outzip = outputZipFile(k, t)
    val script = cfg.outputDir(k, t).resolve("hls").resolve("%s.tcl".format(t.ad.name))
    val logfile = logFile(k, t)
    if (!outzip.toFile.exists) {
      Files.createDirectories(script.getParent) // make output dirs
      new FileWriter(script.toString).append(makeScript(k, t)).close() // write Tcl file
      val runName = "'%s' for %s".format(k.name, t.toString)
      logger.info("starting run {}: output in {}", runName: Any, logfile)
      logfile.toFile.delete
      cfg.verbose foreach { mode =>
        logger.info("verbose mode {} is active, starting to watch {}", mode: Any, logfile)
        lt += logfile
      }

      // execute Vivado HLS (max. runtime: 1 day)
      val vivadoRet = InterruptibleProcess(Process(Seq("vivado_hls",
        "-f", script.toString,
        "-l", logfile.toString
      ), script.getParent.toFile), waitMillis = Some(24 * 60 * 60 * 1000))
        .!(ProcessLogger(line => logger.trace("Vivado HLS: {}", line),
          line => logger.trace("Vivado HLS ERR: {}", line)))
      lt.closeAll
      logger.debug("Vivado HLS finished with exit code %d".format(vivadoRet))
      vivadoRet match {
        case 0 =>
          val cp = copyZip(k, t)
          if(cp.isEmpty) {
            logger.error("Vivado HLS failed for run: {}", runName)
            logger.info("Check Log-File for error: {}", logfile.toAbsolutePath.toString)
            MissingZip(HighLevelSynthesizerLog(logfile))
          } else {
            logger.info("Vivado HLS finished successfully for {}", runName)
            logger.trace("performing additional steps for {}", runName)
            performAdditionalSteps(k, t)
            logger.trace("additional steps for {} finished, copying zip", runName)
            Success(HighLevelSynthesizerLog(logfile), copyZip(k, t).get)
          }
        case InterruptibleProcess.TIMEOUT_RETCODE =>
          logger.error("Vivado HLS timeout for " + runName)
          Timeout(HighLevelSynthesizerLog(logfile))
        case _ =>
          logger.error("Vivado HLS finished with non-zero exit code: " + vivadoRet + " for " + runName)
          VivadoError(HighLevelSynthesizerLog(logfile), vivadoRet)
      }
    } else {
      logger.info("core '%s' already exists in %s, skipping".format(k.name, cfg.outputDir(k, t)))
      Success(HighLevelSynthesizerLog(logfile), outzip)
    }
  } catch {
    case e: Exception =>
      logger.error("Vivado HLS run for '{}' @ {} failed with exception: {}", k.name, t.toString, e)
      logger.debug("stacktrace: {}", e.getStackTrace() mkString NL)
      OtherError(HighLevelSynthesizerLog(logFile(k, t)), e)
  }

  private def makeScript(k: Kernel, t: Target)(implicit cfg: Configuration): String = {
    val tmpl = new Template
    val dirs = k.otherDirectives map (odf =>
      catchDefault("", Seq(classOf[java.io.IOException]), "could not read %s: ".format(odf.toString)) {
        Source.fromFile(odf.toString).getLines.mkString(NL)
      }) getOrElse ""
    tmpl("HEADER") = Seq(
      "set tapasco_freq " + scala.util.Sorting.stableSort(t.pd.supportedFrequencies).reverse.head,
      "source " + Common.commonDir.resolve("common.tcl").toString
    ).mkString(NL)
    tmpl("PROJECT") = t.ad.name
    tmpl("COSIMULATION_FLAG") = if (k.testbenchFiles.length > 0) "1" else "0"
    tmpl("SOLUTION") = "solution"
    tmpl("TOP") = k.topFunction
    tmpl("NAME") = k.name
    tmpl("PART") = t.pd.part
    tmpl("PERIOD") = "[tapasco::get_design_period]"
    tmpl("VENDOR") = "esa.cs.tu-darmstadt.de"
    tmpl("VERSION") = k.version
    tmpl("SOURCES") = k.files mkString " "
    tmpl("SRCSCFLAGS") = k.compilerFlags mkString " "
    tmpl("TBSRCS") = k.testbenchFiles mkString " "
    tmpl("TBCFLAGS") = k.testbenchCompilerFlags mkString " "
    tmpl("TBARGV") = k.testbenchArgv
    tmpl("DIRECTIVES") = Seq(
      kernelArgs(k, t),
      dirs
    ).mkString(NL)
    tmpl.interpolateFile(Common.commonDir.resolve("hls.tcl.template").toString)
  }

  private def kernelArgs(k: Kernel, t: Target): String = {
    import Kernel.PassingConvention._
    val base = 0x20
    val offs = 0x10
    var i = 0
    k.args map { ka => {
      val tmpl = new Template
      tmpl("TOP") = k.topFunction
      tmpl("ARG") = ka.name
      tmpl("OFFSET") = "0x" + (base + i * offs).toHexString
      i += 1
      ka.passingConvention match {
        case ByValue => tmpl.interpolateFile(t.ad.valueArgTemplate.toString)
        case ByReference => tmpl.interpolateFile(t.ad.referenceArgTemplate.toString)
      }
    }
    } mkString NL
  }

  private def copyZip(k: Kernel, t: Target)(implicit cfg: Configuration): Option[Path] = {
    val zips = Common.getFiles(cfg.outputDir(k, t).toFile).filter(_.toString.endsWith(".zip"))

    if (zips.length > 0) {
      val ozip = outputZipFile(k, t)
      val izip = zips(0).getAbsolutePath()
      Files.createDirectories(ozip.getParent)
      logger.debug("Found .zip: " + izip.toString + " copying to " + ozip.toString)

      catchAllDefault(None: Option[Path], "could not copy .zip %s to %s: ".format(izip, ozip.toString)) {
        Files.copy(Paths.get(izip), ozip, StandardCopyOption.REPLACE_EXISTING)
        Some(ozip)
      }
    } else {
      logger.error("No .zip file with IP core found!")
      None
    }
  }

  private def performAdditionalSteps(k: Kernel, t: Target)(implicit cfg: Configuration): Boolean = {
    import scala.reflect.runtime._
    import scala.reflect.runtime.universe._
    import scala.tools.reflect.ToolBox

    lazy val tb = universe.runtimeMirror(this.getClass.getClassLoader).mkToolBox()
    (t.ad.additionalSteps map { step =>
      try {
        // call singleton method 'apply' via reflection
        val stepInst = tb.eval(tb.parse(step))
        val stepInstMirror = universe.runtimeMirror(this.getClass.getClassLoader).reflect(stepInst)
        val meth = stepInstMirror.symbol.typeSignature.member(TermName("apply")).asMethod
        stepInstMirror.reflectMethod(meth)(cfg, t.ad, k)
        true
      } catch {
        case tie: java.lang.reflect.InvocationTargetException =>
          logger.error("Executing additional step '{}' failed: {}", step: Any, tie.getTargetException)
          false
        case e: Throwable =>
          logger.error("Executing additional step '{}' failed: {}", step: Any, e)
          false
      }
    } fold true) (_ && _)
  }
}
