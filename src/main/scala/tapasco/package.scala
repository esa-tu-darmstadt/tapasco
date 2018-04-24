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
package de.tu_darmstadt.cs.esa

/** Tapasco is an automated tool flow for generating
  * threadpool architectures on FPGAs.
  *
  * ==Overview==
  * The Tapasco flow composes hardware threadpools using
  * high-level synthesis and abstract architecture definitions, and
  * provides a uniform programming interface for such threadpools.
  * Its inputs are C/C++ kernels which are suitable for high-level
  * synthesis (see Xilinx UG902 for details on code restrictions),
  * which are composed into a fixed hardware threadpool. At runtime
  * TPC API provides methods to query the threadpool and its
  * currently loaded composition, and to setup, launch and collect
  * jobs to be executed on the threadpool.
  **/
package object tapasco {
  import java.nio.file._
  import scala.io._

  private lazy val REGEX_PLATFORM_NUM_SLOTS = """define\s+PLATFORM_NUM_SLOTS\s+(\d+)""".r

  lazy val PLATFORM_NUM_SLOTS: Int = {
    val f = Paths.get(sys.env("TAPASCO_HOME"))
      .resolve("platform")
      .resolve("include")
      .resolve("platform_global.h")
    assert (f.toFile.exists, s"$f does not exist")
    REGEX_PLATFORM_NUM_SLOTS.findFirstMatchIn(Source.fromFile(f.toString) mkString "")
      .map(_.group(1).toInt)
      .getOrElse(throw new Exception("could not parse PLATFORM_NUM_SLOTS"))
  }
}
