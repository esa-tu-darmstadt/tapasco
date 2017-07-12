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
/**
 * @file     EvaluateIP.scala
 * @brief    Contains the code for the out-of-context synthesis activity.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.activity
import  de.tu_darmstadt.cs.esa.tapasco._
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.util.ZipUtils._
import  Logging._
import  java.nio.file.{Files, Path, Paths}
import  scala.sys.process._
import  scala.xml.XML

/** EvaluateIP is the out-of-context synthesis activity.
  * The EvaluateIP activity performs an out-of-context synthesis and
  * place-and-route of the given IP core and a [[base.Target]] to get an
  * estimate on the area utilization and max. operating frequency
  * of the design. This data can be used in design space exploration.
  * Conventions: There must be a main clock port in the top-level
  * module that contains either 'clk' or 'CLK' in its name.
  */
object EvaluateIP {
  private implicit final val logger =
    de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /** Template for the XML report file (similar to Vivado HLS). */
  final val reportTemplate = Common.commonDir.resolve("ip_report.xml.template")
  /** Template for the out-of-context synth+PnR script. */
  final val tclTemplate = Common.commonDir.resolve("evaluate_ip.tcl.template")

  // custom ProcessIO: ignore everything
  private final val io = new ProcessIO(
    stdin => {stdin.close()},
    stdout => {stdout.close()},
    stderr => {stderr.close()}
  )

  /** Managment of temporary files, directories, reports. */
  private final class Files(zipFile: Path, reportFile: Path) {
    lazy val rpt_timing = reportFile.resolveSibling("timing.rpt")
    lazy val rpt_util   = reportFile.resolveSibling("utilization.rpt")
    lazy val rpt_power  = reportFile.resolveSibling("power.rpt")
    lazy val s_dcp      = reportFile.resolveSibling("out-of-context_synth.dcp")
    lazy val i_dcp      = reportFile.resolveSibling("out-of-context_impl.dcp")
    // unzip relevant files into temporary directory
    lazy val (baseDir, files) = unzipFile(zipFile, Seq(
        """\.v$""".r,
        """\.vhd$""".r,
        """\.xdc$""".r,
        """\.vh$""".r,
        """\.xci$""".r,
        """\.saif$""".r,
        """\.ngc$""".r,
        """subcore.*""".r,
        """component.xml$""".r),
        Seq("""hdl/ip/""".r)
      )
    // partition files
    final private val suflen = 4
    lazy val tcl_files  = files filter (_.toString.endsWith(".tcl"))
    lazy val v_files    = files collect {
      case f if """\.v$""".r.findFirstIn(f.toString).nonEmpty && !includes.contains(f.getFileName) => f
    }
    lazy val vhd_files  = files collect {
      case f if """\.vhd$""".r.findFirstIn(f.toString).nonEmpty &&
                !(v_files map (_.toString) contains (f.toString.dropRight(suflen) + ".v")) &&
                !includes.contains(f.getFileName) => f
    }
    lazy val ngc_files  = files collect {
      case f if """\.ngc$""".r.findFirstIn(f.toString).nonEmpty && !includes.contains(f.getFileName) => f
    }
    lazy val xci_files  = files.collect {
      case f if f.toString.endsWith(".xci") && !includes.contains(f.getFileName) => f
    }
    lazy val hdl_files  = v_files ++ vhd_files
    lazy val logFile    = baseDir.resolve("evaluate.log")
    lazy val tclFile    = baseDir.resolve("evaluate.tcl")
    lazy val ipxact     = files collectFirst { case f if f.toString.endsWith("component.xml") => f }
    lazy val includes   = catchAllDefault[Seq[Path]](Seq[Path](), "could not parse component.xml: ") {
      (XML.loadFile(ipxact.get.toString) \\ "component" \\ "fileSet" filter { fs: scala.xml.Node =>
        (fs \ "name").text equals "xilinx_anylanguagesynthesis_view_fileset"
      }) \ "file" collect {
        case f if (f \ "isIncludeFile").nonEmpty && (f \ "isIncludeFile").text.equals("true") =>
          java.nio.file.Paths.get((f \ "name").text).getFileName
      }
    }
    lazy val netlist   = catchAllDefault[Path](Paths.get("netlist.edn"), "could not parse component.xml: ") {
      reportFile.resolveSibling("%s.edn".format((XML.loadFile(ipxact.get.toString) \\ "component" \\ "name").head.text))
    }
  }

  /** Perform the evaluation.
    * @return true if successful **/
  def apply(zipFile: Path, targetPeriod: Double, targetPart: String, reportFile: Path): Boolean = {
    def deleteOnExit(f: java.io.File) = f.deleteOnExit
    //def deleteOnExit(f: java.io.File) = f        // keep files?

    // logging prefix
    val runPrefix = "evaluation of %s for %s@%1.3f MHz".format(zipFile, targetPart, 1000.0 / targetPeriod)

    // define report filenames
    Files.createDirectories(reportFile.getParent)
    val files = new Files(zipFile, reportFile)
    writeTclScript(files, targetPart, targetPeriod)

    logger.info("starting {}, output in {}", runPrefix: Any, files.logFile)

    val vivadoCmd = Seq("vivado",
        "-mode", "batch",
        "-source", files.tclFile.toString,
        "-log", files.logFile.toString,
        "-notrace", "-nojournal")

    logger.trace("Vivado command: {}", vivadoCmd mkString " ")

    // execute Vivado (max runtime: 1d)
    val r = InterruptibleProcess(Process(vivadoCmd, files.baseDir.toFile),
        waitMillis = Some(24 * 60 * 60 * 1000)).!(io)

    if (r == InterruptibleProcess.TIMEOUT_RETCODE) {
      logger.error("%s: Vivado timeout error".format(runPrefix))
    } else {
      if (r == 0) {
        logger.trace("%s: Vivado finished successfully".format(runPrefix))
        val ur  = UtilizationReport(files.rpt_util).get
        val dpd = TimingReport(files.rpt_timing).get.dataPathDelay
        writeXMLReport(reportFile, ur, dpd, targetPeriod)
        logger.info("{} finished successfully, report in {}", runPrefix: Any, reportFile)
        // clean up files on exit
        deleteOnExit(files.baseDir.toFile)
        deleteOnExit(files.baseDir.resolve(".Xil").toFile) // also remove Xilinx's crap
        files.files.map(f => deleteOnExit(f.toFile)) // remove files from zip only on success, else keep
        deleteOnExit(files.tclFile.toFile)
        deleteOnExit(files.logFile.toFile)
      } else {
        logger.error("%s: Vivado finished with error (%d)".format(runPrefix, r))
      }
    }
    r == 0
  }

  /**
   * Writes the Tcl script for the out-of-context run.
   * @param files [[Files]] object for this run.
   * @param targetPart Part identifier of the target FPGA.
   * @param targetPeriod Target operating period.
   **/
  private def writeTclScript(files: Files, targetPart: String, targetPeriod: Double): Unit = {
    val needles: scala.collection.mutable.Map[String, String] = scala.collection.mutable.Map(
      "SRC_FILES"          -> (files.hdl_files map (_.toString) mkString " "),
      "TCL_FILES"          -> (files.tcl_files mkString " "),
      "NGC_FILES"          -> (files.ngc_files mkString " "),
      "XCI_FILES"          -> (files.xci_files mkString " "),
      "PART"               -> targetPart,
      "PERIOD"             -> targetPeriod.toString,
      "REPORT_TIMING"      -> files.rpt_timing.toString,
      "REPORT_UTILIZATION" -> files.rpt_util.toString,
      "REPORT_POWER"       -> files.rpt_power.toString,
      "SYNTH_CHECKPOINT"   -> files.s_dcp.toString,
      "IMPL_CHECKPOINT"    -> files.i_dcp.toString,
      "NETLIST"            -> files.netlist.toString
    )

    // write Tcl script
    Template.interpolateFile(
        Template.DEFAULT_NEEDLE,
        tclTemplate.toString,
        files.tclFile.toString,
        needles)
  }

  /**
   * Writes the output report in XML format (similar to Vivado HLS).
   * @param reportFile Output file name.
   * @param ur [[UtilizationReport]] instance.
   * @param dataPathDelay Delay on longest combinatorial path in datapath.
   * @param targetPeriod Target operating period.
   **/
  private def writeXMLReport(reportFile: Path, ur: UtilizationReport, dataPathDelay: Double,
      targetPeriod: Double): Unit = {
    val needles = scala.collection.mutable.Map[String, String](
      "SLICE"      -> ur.used.SLICE.toString,
      "SLICES"     -> ur.available.SLICE.toString,
      "LUT"        -> ur.used.LUT.toString,
      "LUTS"       -> ur.available.LUT.toString,
      "FF"         -> ur.used.FF.toString,
      "FFS"        -> ur.available.FF.toString,
      "BRAM"       -> ur.used.BRAM.toString,
      "BRAMS"      -> ur.available.BRAM.toString,
      "DSP"        -> ur.used.DSP.toString,
      "DSPS"       -> ur.available.DSP.toString,
      "PERIOD"     -> targetPeriod.toString,
      "MIN_PERIOD" -> dataPathDelay.toString
    )

    // write final report
    Template.interpolateFile(
        Template.DEFAULT_NEEDLE,
        reportTemplate.toString,
        reportFile.toString,
        needles
    )
  }
}
