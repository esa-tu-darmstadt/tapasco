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
 * @file     EntityManagerTest.scala
 * @brief    Unit tests for EntityManager.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  org.scalatest._
import  java.nio.file._

class FileAssetManagerSpec extends FlatSpec with Matchers {
  private final val TAPASCO_HOME = Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath.normalize
  private final val FS_SLEEP = 500
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  "Changes in the base paths" should "be reflected in the caches" in {
    var oldpath = FileAssetManager.basepath(Entities.Architectures).get
    var oldnum = FileAssetManager.entities.architectures.size
    FileAssetManager.basepath(Entities.Architectures).set(
      TAPASCO_HOME.resolve("json-examples").resolve("configTest").resolve("arch"))
    assert(FileAssetManager.entities.architectures.size == 3)
    FileAssetManager.basepath(Entities.Architectures).set(oldpath)
    assert(FileAssetManager.entities.architectures.size == oldnum)

    oldpath = FileAssetManager.basepath(Entities.Platforms).get
    oldnum = FileAssetManager.entities.platforms.size
    FileAssetManager.basepath(Entities.Platforms).set(
      TAPASCO_HOME.resolve("json-examples").resolve("configTest").resolve("platform"))
    assert(FileAssetManager.entities.platforms.size == 3)
    FileAssetManager.basepath(Entities.Platforms).set(oldpath)
    assert(FileAssetManager.entities.platforms.size == oldnum)

    oldpath = FileAssetManager.basepath(Entities.Kernels).get
    oldnum = FileAssetManager.entities.kernels.size
    FileAssetManager.basepath(Entities.Kernels).set(
      TAPASCO_HOME.resolve("json-examples").resolve("configTest").resolve("kernel"))
    assert(FileAssetManager.entities.kernels.size == 3)
    FileAssetManager.basepath(Entities.Kernels).set(oldpath)
    assert(FileAssetManager.entities.kernels.size == oldnum)
  }

  "Creating new core.jsons during runtime" should "be reflected in the caches" in {
    val p = Files.createTempDirectory("tapasco-fileassetmanager-")
    val d = p.resolve("Test").resolve("axi4mm").resolve("vc709").resolve("ipcore")
    Files.createDirectories(d)
    FileAssetManager.basepath(Entities.Cores).set(p)
    assert(FileAssetManager.entities.cores.size == 0)
    val zip = d.resolve("test_axi4mm.zip")
    val cf = d.resolve("core.json")
    Files.createFile(zip)
    val t = Target(FileAssetManager.entities.architectures.toSeq.head, FileAssetManager.entities.platforms.toSeq.head)
    val core = Core(cf, zip, "Test", 42, "0.0.1", t, None, None)
    Core.to(core, cf)

    assert(FileAssetManager.entities.cores.size == 1)
    val c = FileAssetManager.entities.cores.toSeq.head
    assert(c equals core)

    cf.toFile().deleteOnExit()
    zip.toFile().deleteOnExit()
    p.toFile().deleteOnExit()
  }
}
