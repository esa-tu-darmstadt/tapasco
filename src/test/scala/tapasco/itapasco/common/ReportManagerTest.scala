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
/**
 * @file     ReportManagerTest.scala
 * @brief    Unit tests for ReportManager.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  org.scalatest._
import  java.nio.file._
import  java.nio.file.attribute.BasicFileAttributes

class ReportManagerSpec extends FlatSpec with Matchers {
  private final val TAPASCO_HOME = Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath.normalize
  private final val FS_SLEEP = 500
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private def markForDeletion(p: Path): Unit = {
    val visitor = new SimpleFileVisitor[Path] {
      override def preVisitDirectory(p: Path, bfa: BasicFileAttributes) = {
        p.toFile.deleteOnExit()
        FileVisitResult.CONTINUE
      }
      override def visitFile(p: Path, bfa: BasicFileAttributes) = {
        p.toFile.deleteOnExit()
        FileVisitResult.CONTINUE
      }
    }
    Files.walkFileTree(p, visitor)
  }

  private def setupStructure(p: Path): (Path, Path, Path, Path) = {
    val cosimPath = p.resolve("arraysum").resolve("axi4mm").resolve("vc709").resolve("ipcore")
    val powerPath = p.resolve("arrayinit").resolve("blueline").resolve("zedboard").resolve("ipcore")
    val synthPath = p.resolve("aes").resolve("blackline").resolve("zc706").resolve("ipcore")
    val timingPath = p.resolve("test").resolve("axi4mm").resolve("zc706").resolve("ipcore")
    Files.createDirectories(cosimPath)
    Files.createDirectories(powerPath)
    Files.createDirectories(synthPath)
    Files.createDirectories(timingPath)
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-cosim1.rpt"),
      cosimPath.resolve("arraysum_cosim.rpt"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-power1.rpt"),
      powerPath.resolve("power.rpt"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth1.rpt"),
      synthPath.resolve("aes_export.xml"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-timing.rpt"),
      timingPath.resolve("timing.rpt"))
    (cosimPath, powerPath, synthPath, timingPath)
  }

  "All reports in existing directory structure" should "be found and built correctly" in {
    import Entities._
    val p = Files.createTempDirectory("tapasco-reportcache-").resolve("core")
    setupStructure(p)
    val bpm = new BasePathManager
    bpm.basepath(Cores).set(p)
    val rc = new ReportManager(bpm.basepath(Cores))
    bpm += rc.basePathListener
    assert(rc.timingReports.size == 1)
    assert(rc.synthReports.size == 1)
    assert(rc.powerReports.size == 1)
    assert(rc.timingReports.size == 1)

    val r1 = rc.cosimReport("arraysum", "axi4mm", "vc709")
    assert(r1.nonEmpty)
    assert(r1.get.latency.avg == 280)

    val r2 = rc.powerReport("arrayinit", "blueline", "zedboard")
    assert(r2.nonEmpty)
    assert(r2.get.totalOnChipPower map (_ == 0.33) getOrElse false)

    val r3 = rc.synthReport("aes", "blackline", "zc706")
    assert(r3.nonEmpty)
    assert(r3.get.area.nonEmpty)
    assert(r3.get.area.get.resources.FF == 776)

    val r4 = rc.timingReport("test", "axi4mm", "zc706")
    assert(r4.nonEmpty)
    assert(r4.get.worstNegativeSlack == -5.703)

    markForDeletion(p)
  }

  "Modification and deletion of source files" should "be reflected automatically" in {
    import Entities._
    val p = Files.createTempDirectory("tapasco-reportcache-").resolve("core")
    val dw = DirectoryWatcher(p)
    val (p1, p2, p3, p4) = setupStructure(p)
    val bpm = new BasePathManager
    bpm.basepath(Cores).set(p)
    val rc = new ReportManager(bpm.basepath(Cores))
    bpm += rc.basePathListener
    dw += rc.directoryListener
    dw.start()

    assert(rc.timingReports.size == 1)
    assert(rc.synthReports.size == 1)
    assert(rc.powerReports.size == 1)
    assert(rc.timingReports.size == 1)

    val r1 = rc.cosimReport("arraysum", "axi4mm", "vc709")
    assert(r1.nonEmpty)
    assert(r1.get.latency.avg == 280)

    logger.info("{} -> {}", TAPASCO_HOME.resolve("report-examples").resolve("correct-cosim2.rpt"): Any, r1.get.file)
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-cosim2.rpt"), r1.get.file,
      StandardCopyOption.REPLACE_EXISTING)
    Thread.sleep(FS_SLEEP)

    val r2 = rc.cosimReport("arraysum", "axi4mm", "vc709")
    assert(r2.nonEmpty)
    assert(r2.get.latency.avg == 2279)

    val r3 = rc.powerReport("arrayinit", "blueline", "zedboard")
    assert(r3.nonEmpty)

    Files.delete(r3.get.file)
    Thread.sleep(FS_SLEEP)

    assert(rc.powerReports.size == 0)

    dw.stop()
    markForDeletion(p)
  }

  "Changing the base path" should "be correctly reflected in the cache" in {
    import Entities._
    val p1 = Files.createTempDirectory("tapasco-reportcache-")
    val p2 = Files.createTempDirectory("tapasco-reportcache-")
    setupStructure(p1)
    val bpm = new BasePathManager
    bpm.basepath(Cores).set(p1)
    val rc = new ReportManager(bpm.basepath(Cores))
    bpm += rc.basePathListener

    assert(rc.timingReports.size == 1)
    assert(rc.synthReports.size == 1)
    assert(rc.powerReports.size == 1)
    assert(rc.timingReports.size == 1)

    bpm.basepath(Cores).set(p2)

    assert(rc.timingReports.size == 0)
    assert(rc.synthReports.size == 0)
    assert(rc.powerReports.size == 0)
    assert(rc.timingReports.size == 0)

    markForDeletion(p1)
    markForDeletion(p2)
  }
}
