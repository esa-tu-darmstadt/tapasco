package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.language.implicitConversions
import  java.nio.file.{Path, Paths}

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
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  sealed trait Event
  final case class BasePathChanged(base: Entity, path: Path) extends Event

  /** Base directory of TPC, set by TAPASCO_HOME environmment variable. **/
  final private val TAPASCO_HOME = try {
    Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath().normalize
  } catch { case e: NoSuchElementException =>
    logger.error("FATAL: TAPASCO_HOME environment variable is not set")
    throw e
  }

  /** Default directory: Architectures. **/
  final val DEFAULT_DIR_ARCHS        = TAPASCO_HOME.resolve("arch")

  /** Default directory: Bitstreams. **/
  final val DEFAULT_DIR_COMPOSITIONS = TAPASCO_HOME.resolve("bd")

  /** Default directory: Cores. **/
  final val DEFAULT_DIR_CORES        = TAPASCO_HOME.resolve("core")

  /** Default directory: Kernels. **/
  final val DEFAULT_DIR_KERNELS      = TAPASCO_HOME.resolve("kernel")

  /** Default directory: Platforms. **/
  final val DEFAULT_DIR_PLATFORMS    = TAPASCO_HOME.resolve("platform")

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
