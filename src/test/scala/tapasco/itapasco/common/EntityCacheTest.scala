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
 * @file     EntityCacheTest.scala
 * @brief    Unit tests for EntityCache.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  org.scalatest._
import  java.nio.file._
import  java.nio.file.attribute.BasicFileAttributes

class EntityCacheSpec extends FlatSpec with Matchers {
  private final val TAPASCO_HOME = Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath.normalize
  private final val FS_SLEEP = 500

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

  private def setupStructure(p: Path): (Path, Path, Path) = {
    val p1 = p.resolve("a")
    val p2 = p.resolve("b").resolve("b1")
    val p3 = p.resolve("c").resolve("c1").resolve("c2")
    Files.createDirectories(p1)
    Files.createDirectories(p2)
    Files.createDirectories(p3)
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth1.rpt"), p.resolve("synth.rpt"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth1.rpt"), p1.resolve("synth.rpt"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth2.rpt"), p2.resolve("synth.rpt"))
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth3.rpt"), p3.resolve("synth.rpt"))
    markForDeletion(p)
    (p1, p2, p3)
  }

  "All matching files in existing directory structure" should "be found and built correctly" in {
    val p = Files.createTempDirectory("tapasco-entitycachespec-")
    val (p1, p2, p3) = setupStructure(p)
    val dw = DirectoryWatcher(p)
    val ec = EntityCache(Set(p), """synth.rpt$""".r.unanchored, SynthesisReport.apply _)
    dw += ec
    dw.start()
    assert(ec.files.size == 4)
    assert(ec.entities.size == 4)
    val r1 = ec.entities find (_.file.startsWith(p.resolve("synth.rpt")))
    assert(r1.nonEmpty)
    assert(r1.get.area map (_.resources.LUT == 538) getOrElse false)
    assert(r1.get.area map (_.available.SLICE == 13300) getOrElse false)
    val r2 = ec.entities find (_.file.startsWith(p1.resolve("synth.rpt")))
    assert(r2.nonEmpty)
    assert(r2.get.area map (_.resources.LUT == 538) getOrElse false)
    assert(r2.get.area map (_.available.SLICE == 13300) getOrElse false)
    val r3 = ec.entities find (_.file.startsWith(p2.resolve("synth.rpt")))
    assert(r3.nonEmpty)
    assert(r3.get.timing map (_.clockPeriod == 2.65) getOrElse false)
    assert(r3.get.area map (_.available.DSP == 900) getOrElse false)
    val r4 = ec.entities find (_.file.startsWith(p3.resolve("synth.rpt")))
    assert(r4.nonEmpty)
    assert(r4.get.area map (_.resources.FF == 779) getOrElse false)
    assert(r4.get.area map (_.available.BRAM == 1470) getOrElse false)
    markForDeletion(p)
  }

  "All matching files in dynamically setup directory structure" should "be found and built correctly" in {
    val p = Files.createTempDirectory("tapasco-entitycachespec-")
    val dw = DirectoryWatcher(p)
    val ec = EntityCache(Set(p), """synth.rpt$""".r.unanchored, SynthesisReport.apply _)
    dw += ec
    dw.start()
    assert(ec.files.size == 0)
    assert(ec.entities.size == 0)
    val (p1, p2, p3) = setupStructure(p)
    Thread.sleep(FS_SLEEP)
    val r1 = ec.entities find (_.file.startsWith(p.resolve("synth.rpt")))
    assert(r1.nonEmpty)
    assert(r1.get.area map (_.resources.LUT == 538) getOrElse false)
    assert(r1.get.area map (_.available.SLICE == 13300) getOrElse false)
    val r2 = ec.entities find (_.file.startsWith(p1.resolve("synth.rpt")))
    assert(r2.nonEmpty)
    assert(r2.get.area map (_.resources.LUT == 538) getOrElse false)
    assert(r2.get.area map (_.available.SLICE == 13300) getOrElse false)
    val r3 = ec.entities find (_.file.startsWith(p2.resolve("synth.rpt")))
    assert(r3.nonEmpty)
    assert(r3.get.timing map (_.clockPeriod == 2.65) getOrElse false)
    assert(r3.get.area map (_.available.DSP == 900) getOrElse false)
    val r4 = ec.entities find (_.file.startsWith(p3.resolve("synth.rpt")))
    assert(r4.nonEmpty)
    assert(r4.get.area map (_.resources.FF == 779) getOrElse false)
    assert(r4.get.area map (_.available.BRAM == 1470) getOrElse false)
    markForDeletion(p)
  }

  "Cached entities" should "be rebuild upon modifications to source file" in {
    val p = Files.createTempDirectory("tapasco-entitycachespec-")
    val dw = DirectoryWatcher(p)
    val ec = EntityCache(Set(p), """synth.rpt$""".r.unanchored, SynthesisReport.apply _)
    dw += ec
    dw.start()
    assert(ec.files.size == 0)
    assert(ec.entities.size == 0)
    val (p1, p2, p3) = setupStructure(p)
    Thread.sleep(FS_SLEEP)
    val r1 = ec.entities find (_.file.startsWith(p.resolve("synth.rpt")))
    assert(r1.nonEmpty)
    assert(r1.get.area map (_.resources.LUT == 538) getOrElse false)
    assert(r1.get.area map (_.available.SLICE == 13300) getOrElse false)
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("correct-synth3.rpt"), p.resolve("synth.rpt"),
        StandardCopyOption.REPLACE_EXISTING)
    Thread.sleep(FS_SLEEP)
    val r2 = ec.entities find (_.file.startsWith(p.resolve("synth.rpt")))
    assert(r2.nonEmpty)
    assert(r2.get.area map (_.resources.FF == 779) getOrElse false)
    assert(r2.get.area map (_.available.BRAM == 1470) getOrElse false)
    Files.copy(TAPASCO_HOME.resolve("report-examples").resolve("invalid-synth1.rpt"), p3.resolve("synth.rpt"),
        StandardCopyOption.REPLACE_EXISTING)
    Thread.sleep(FS_SLEEP)
    val r3 = ec.entities find (_.file.startsWith(p3.resolve("synth.rpt")))
    assert(r3.isEmpty)
    markForDeletion(p)
  }

  "Cached entities" should "be removed upon deletion of source file" in {
    val p = Files.createTempDirectory("tapasco-entitycachespec-")
    val (p1, p2, p3) = setupStructure(p)
    val dw = DirectoryWatcher(p)
    val ec = EntityCache(Set(p), """synth.rpt$""".r.unanchored, SynthesisReport.apply _)
    dw += ec
    dw.start()
    assert(ec.files.size == 4)
    assert(ec.entities.size == 4)

    val r1 = ec.entities find (_.file.startsWith(p2.resolve("synth.rpt")))
    assert(r1.nonEmpty)
    while(! p2.resolve("synth.rpt").toFile().delete()) {}
    Thread.sleep(FS_SLEEP)
    assert(ec.files.size == 3)
    assert(ec.entities.size == 3)
    val r2 = ec.entities find (_.file.startsWith(p2.resolve("synth.rpt")))
    assert(r2.isEmpty)
    markForDeletion(p)
  }
}
