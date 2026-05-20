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

import java.nio.file.Paths

import org.scalatest.Matchers
import tapasco.TaPaSCoSpec

class VivadoHighLevelSynthesisSpec extends TaPaSCoSpec with Matchers {
  "selectHLSCommand" should "fall back to vitis-run for Vitis 2025.1+" in {
    VivadoHighLevelSynthesis.selectHLSCommand {
      case Seq("vitis_hls", "-version") => false
      case Seq("vivado_hls", "-version") => false
      case Seq("vitis-run", "--mode", "hls", "--help") => true
      case _ => false
    } shouldBe Some("vitis-run")
  }

  it should "keep preferring vitis_hls when both frontends are available" in {
    VivadoHighLevelSynthesis.selectHLSCommand(_ => true) shouldBe Some("vitis_hls")
  }

  "buildHLSCommand" should "use vitis-run HLS arguments for the unified Vitis frontend" in {
    val script = Paths.get("/tmp/hls.tcl")
    val logfile = Paths.get("/tmp/hls.log")

    VivadoHighLevelSynthesis.buildHLSCommand("vitis-run", script, logfile, 24 * 60 * 60) shouldBe
      Seq("timeout", "86400", "vitis-run", "--mode", "hls", "--tcl", "--input_file", script.toString)
  }

  it should "keep legacy arguments for vitis_hls" in {
    val script = Paths.get("/tmp/hls.tcl")
    val logfile = Paths.get("/tmp/hls.log")

    VivadoHighLevelSynthesis.buildHLSCommand("vitis_hls", script, logfile, 24 * 60 * 60) shouldBe
      Seq("timeout", "86400", "vitis_hls", "-f", script.toString, "-l", logfile.toString)
  }
}
