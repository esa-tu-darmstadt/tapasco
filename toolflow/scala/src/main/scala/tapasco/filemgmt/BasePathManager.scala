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
package tapasco.filemgmt

import java.nio.file.{Path, Paths}

import tapasco.util._

import scala.language.implicitConversions

class BasePathManager(createOnSet: Boolean = true) extends Publisher {
  type Event = BasePathManager.Event

  val basepath: Map[Entity, BasePath] = (Entities() map { e =>
    val (path, cos) = BasePathManager.defaultDirectory(e)
    val bp = new BasePath(path, createOnSet && cos)
    bp += new Listener[BasePath.Event] {
      def update(v: BasePath.Event): Unit =
        v match { case BasePath.BasePathChanged(p) => publish(BasePathManager.BasePathChanged(e, p)) }
    }
    e -> bp
  }).toMap
}

object BasePathManager {
  private final val logger = tapasco.Logging.logger(getClass)

  sealed trait Event
  final case class BasePathChanged(base: Entity, path: Path) extends Event

  /** Base directory of TPC, set by TAPASCO_HOME environmment variable. **/
  final private val TAPASCO_HOME = try {
    Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath().normalize
  } catch { case e: NoSuchElementException =>
    logger.error("FATAL: TAPASCO_HOME environment variable is not set")
    throw e
  }

  /** Working directory of TaPaSCo, set by TAPASCO_WORK_DIR environmment variable. **/
  final private val TAPASCO_WORK_DIR = try {
    Paths.get(sys.env("TAPASCO_WORK_DIR")).toAbsolutePath().normalize
  } catch { case e: NoSuchElementException =>
    logger.error("FATAL: TAPASCO_WORK_DIR environment variable is not set")
    throw e
  }

  /** Default directory: Architectures. **/
  final val DEFAULT_DIR_ARCHS        = TAPASCO_HOME.resolve("toolflow").resolve("TCL").resolve("arch")

  /** Default directory: Bitstreams. **/
  final val DEFAULT_DIR_COMPOSITIONS = TAPASCO_WORK_DIR.resolve("compose")

  /** Default directory: Cores. **/
  final val DEFAULT_DIR_CORES        = TAPASCO_WORK_DIR.resolve("core")

  /** Default directory: Kernels. **/
  final val DEFAULT_DIR_KERNELS      = TAPASCO_WORK_DIR.resolve("kernel")

  /** Default directory: Platforms. **/
  final val DEFAULT_DIR_PLATFORMS    = TAPASCO_HOME.resolve("toolflow").resolve("TCL").resolve("platform")

  /** Map of default directories for entities. */
  lazy final val defaultDirectory: Map[Entity, (Path, Boolean)] = Map(
    Entities.Architectures -> (DEFAULT_DIR_ARCHS, false),
    Entities.Cores         -> (DEFAULT_DIR_CORES, true),
    Entities.Compositions  -> (DEFAULT_DIR_COMPOSITIONS, true),
    Entities.Kernels       -> (DEFAULT_DIR_KERNELS, false),
    Entities.Platforms     -> (DEFAULT_DIR_PLATFORMS, false)
  )

  /** Implicit conversion: BasePathManager to map of entities to paths. */
  implicit def toMap(bpm: BasePathManager): Map[Entity, BasePath] = bpm.basepath
}
