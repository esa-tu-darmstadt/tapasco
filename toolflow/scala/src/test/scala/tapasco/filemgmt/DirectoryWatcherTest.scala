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
 * @file     DirectoryWatcherTest.scala
 * @brief    Unit tests for DirectoryWatcher.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  org.scalatest._
import  java.nio.file._

class DirectoryWatcherSpec extends FlatSpec with Matchers {
  private final val FS_SLEEP = 500
  "Creating a file in a watched directory" should "generate a Create event" in {
    val p = Files.createTempDirectory(Paths.get("/tmp"), "tapasco-directorywatcherspec-")
    p.toFile.deleteOnExit()
    val dw = DirectoryWatcher(p)
    var ok = false
    dw += new Listener[DirectoryWatcher.Event] {
      def update(e: DirectoryWatcher.Event): Unit = e match {
        case DirectoryWatcher.Events.Create(p) => ok = true
        case _ => {}
      }
    }
    dw.start()
    val f = Files.createTempFile(p, "test", "txt")
    f.toFile.deleteOnExit()
    Thread.sleep(FS_SLEEP)
    dw.stop()
    assert(ok)
  }

  "Modifying a file in a watched directory" should "generate a Modify event" in {
    val p = Files.createTempDirectory(Paths.get("/tmp"), "tapasco-directorywatcherspec-")
    p.toFile.deleteOnExit()
    val dw = DirectoryWatcher(p)
    var ok = false
    dw += new Listener[DirectoryWatcher.Event] {
      def update(e: DirectoryWatcher.Event): Unit = e match {
        case DirectoryWatcher.Events.Modify(p) => ok = true
        case _ => {}
      }
    }
    val f = Files.createTempFile(p, "test", "txt")
    f.toFile.deleteOnExit()
    Thread.sleep(FS_SLEEP)
    dw.start()
    Files.setLastModifiedTime(f, java.nio.file.attribute.FileTime.fromMillis(42))
    Thread.sleep(FS_SLEEP)
    dw.stop()
    assert(ok)
  }

  "Deleting a file in a watched directory" should "generate a Delete event" in {
    val p = Files.createTempDirectory(Paths.get("/tmp"), "tapasco-directorywatcherspec-")
    p.toFile.deleteOnExit()
    val dw = DirectoryWatcher(p)
    var ok = false
    dw += new Listener[DirectoryWatcher.Event] {
      def update(e: DirectoryWatcher.Event): Unit = e match {
        case DirectoryWatcher.Events.Delete(p) => ok = true
        case _ => {}
      }
    }
    val f = Files.createTempFile(p, "test", "txt")
    Thread.sleep(FS_SLEEP)
    dw.start()
    Files.delete(f)
    Thread.sleep(FS_SLEEP)
    dw.stop()
    assert(ok)
  }

  "Creating, modifying and deleting files in arbitrary subdirs of a watched directory" should
  "generate Create, Modify and Delete events" in {
    val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
    val p = Files.createTempDirectory(Paths.get("/tmp"), "tapasco-directorywatcherspec-")
    p.toFile.deleteOnExit()
    val s = p.resolve("a").resolve("b").resolve("c")
    val f = s.resolve("test.txt")
    val dw = DirectoryWatcher(p)
    var ok_create = false
    var ok_modify = false
    var ok_delete = false
    dw += new Listener[DirectoryWatcher.Event] {
      def update(e: DirectoryWatcher.Event): Unit = { logger.trace("event: {}", e); e match {
        case DirectoryWatcher.Events.Create(p) => ok_create |= p.equals(f)
        case DirectoryWatcher.Events.Modify(p) => ok_modify |= p.equals(f)
        case DirectoryWatcher.Events.Delete(p) => ok_delete |= p.equals(f) || f.startsWith(p)
        case _ => {}
      }}
    }
    dw.start()

    Files.createDirectories(s)
    Files.createFile(f)
    Thread.sleep(FS_SLEEP)
    Files.setLastModifiedTime(f, java.nio.file.attribute.FileTime.fromMillis(0))
    Thread.sleep(FS_SLEEP)
    Files.delete(f)

    var countdown = 5
    while (countdown > 0 && (! ok_create || ! ok_modify || ! ok_delete)) {
      Thread.sleep(FS_SLEEP)
      countdown -= 1
    }
    dw.stop()
    assert(ok_create, "no create event received")
    assert(ok_modify, "no modify event received")
    assert(ok_delete, "no delete event received")
  }
}

