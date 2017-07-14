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
 * @file     BasePathManagerTest.scala
 * @brief    Unit tests for BasePathManager.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  org.scalatest._
import  java.nio.file._

class BasePathManagerSpec extends FlatSpec with Matchers {
  "A BasePathManager" should "generate a correct event for a change on any entity" in {
    val bpm = new BasePathManager(false)
    var await: Entity = Entities.Architectures
    var path: Path = Paths.get("N-A")
    var ok = true

    bpm += new Listener[BasePathManager.Event] {
      def update(e: BasePathManager.Event): Unit = e match {
        case BasePathManager.BasePathChanged(t, p) => ok = ok && await.equals(t) && path.equals(p)
      }
    }

    for (a <- Entities()) {
      await = a
      path = Paths.get(a.toString)
      bpm(a).set(path)
    }

    assert(ok)
  }

  "A BasePathManager" should "not generate events, when set path is the same" in {
    val bpm = new BasePathManager(false)
    var ok = true
    bpm += new Listener[BasePathManager.Event] { def update(e: BasePathManager.Event): Unit = ok = false }
    for (a <- Entities()) { bpm(a).set(bpm(a).get) }
    assert(ok)
  }

  "Parallel changes with unique paths" should "generate an event for each change" in {
    import java.util.concurrent.atomic.AtomicInteger
    import scala.concurrent.Future
    import scala.concurrent.ExecutionContext.Implicits.global

    val tests = 1000000
    val count = new AtomicInteger(tests)
    val check = new Array[Boolean](tests)
    val p = Paths.get(".")
    val bpm = new BasePathManager(false)

    0 until tests foreach { i => check(i) = false }

    bpm += new Listener[BasePathManager.Event] {
      def update(e: BasePathManager.Event): Unit = e match {
        case BasePathManager.BasePathChanged(_, np) => check(np.getFileName().toString.toInt) = true
      }
    }

    val futures = for { i <- 0 until count.get() } yield Future {
      var i = count.getAndDecrement()
      while (i >= 0) {
        bpm(Entities()(i % Entities().length)).set(p.resolve("%d".format(i)))
        i = count.getAndDecrement()
      }
    }

    futures foreach { f => scala.concurrent.Await.ready(f, scala.concurrent.duration.Duration.Inf) }

    assert(0 until tests map { i => check(i) } reduce (_ && _))
  }
}
