package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.util.matching._
import  java.nio.file._

class EntityManager(val bpm: BasePathManager) extends Publisher {
  private val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  type Event = EntityManager.Event

  /** Reset all caches. */
  def reset(): Unit = { _caches.values foreach { _.clear() } }

  /** Clear caches and set optional new paths. */
  def clear(p: Option[Set[Path]] = None): Unit = _caches.values foreach { _.clear(p) }

  /** Returns the entity cache for the given entity kind. */
  def apply(e: Entity): EntityCache[_] = _caches(e)

  /* @{ accessors for entities */
  /** Returns all Architectures in current base path. **/
  def architectures: Set[Architecture]                       = _archCache.entities
  /** Returns Architectures for given description file paths. **/
  def architectures(paths: Path*): Seq[Option[Architecture]] = _archCache(paths: _*)

  /** Returns all Cores in current base path. **/
  def cores: Set[Core]                                       = _coreCache.entities
  /** Returns Cores for given description file paths. **/
  def cores(paths: Path*): Seq[Option[Core]]                 = _coreCache(paths: _*)
  /** Returns a Core for the given kernel name and target (if any). */
  def core(name: String, target: Target): Option[Core] =
    (cores filter { c => c.name.equals(name) && c.target.equals(target) }).toSeq.headOption

  /** Returns all Platforms in current base path. **/
  def platforms: Set[Platform]                               = _platformCache.entities
  /** Returns Platforms for given description file paths. **/
  def platforms(paths: Path*): Seq[Option[Platform]]         = _platformCache(paths: _*)

  /** Returns all Kernels in current base path. **/
  def kernels: Set[Kernel]                                   = _kernelCache.entities
  /** Returns Kernels for given description file paths. **/
  def kernels(paths: Path*): Seq[Option[Kernel]]             = _kernelCache(paths: _*)

  /** Returns all Targets. */
  def targets: Set[Target] = for {
    p <- platforms
    a <- architectures
  } yield Target(a, p)
  /* @} */

  /* @{ Listeners */
  /** Listener for directory watcher events: will forward to all caches. */
  val directoryListener = new Listener[DirectoryWatcher.Event] {
    def update(e: DirectoryWatcher.Event): Unit =  Entities() foreach { ent =>
      if (e.path.startsWith(bpm.basepath(ent))) _caches(ent).update(e)
    }
  }

  private val _entityCacheListener = new Listener[EntityCache.Event] {
    import EntityManager.Events._
    def update(e: EntityCache.Event): Unit = e match {
      case EntityCache.Events.Changed(ec, p, k) =>
        _logger.trace("received Changed({}, {}, {})", ec, p, k)
        _caches find { case (_, c) => c equals ec } foreach { case (e, _) => publish(Changed(e, p, k)) }
      case EntityCache.Events.Cleared(ec, nps) =>
        _logger.trace("received Cleared({}, {})", ec:Any, nps:Any)
        val entity = _caches find { case (_, c) => c equals ec }
        if (! entity.isEmpty) {
          entity foreach { case (e, _) => publish(Cleared(e)) }
        }
    }
  }
  /* Listeners @} */

  /* @{ Internals */
  /** Internal map of description regexes. **/
  private val _filters: Map[Entity, Regex] = Map(
    Entities.Architectures -> """architecture.json$""".r.unanchored,
    Entities.Compositions  -> """composition.json$""".r.unanchored,
    Entities.Cores         -> """core.json$""".r.unanchored,
    Entities.Kernels       -> """kernel.json$""".r.unanchored,
    Entities.Platforms     -> """platform.json$""".r.unanchored
  )

  /** Issue warning for failed builds (at least once). */
  private def checkBuild[T](kind: String, p: Path, build: Option[T]): Option[T] = {
    if (build.isEmpty) _logger.warn("could not build {} from file: '{}'", kind: Any, p)
    build
  }
  private def buildArch(p: Path): Option[Architecture] = checkBuild("Architecture", p, Architecture.from(p).toOption)
  private def buildComposition(p: Path): Option[Composition] = checkBuild("Composition", p, Composition.from(p).toOption)
  private def buildCore(p: Path): Option[Core] = checkBuild("Core", p, Core.from(p).toOption)
  private def buildKernel(p: Path): Option[Kernel] = checkBuild("Kernel", p, Kernel.from(p).toOption)
  private def buildPlatform(p: Path): Option[Platform] = checkBuild("Platform", p, Platform.from(p).toOption)

  /** EntityCache instance for Architectures. **/
  private val _archCache = EntityCache(Set(bpm.basepath(Entities.Architectures)),
      _filters(Entities.Architectures), buildArch _)
  /** EntityCache instance for Compositions. **/
  private val _compositionCache = EntityCache(Set(bpm.basepath(Entities.Compositions)),
      _filters(Entities.Compositions), buildComposition _)
  /** EntityCache instance for Cores. **/
  private val _coreCache = EntityCache(Set(bpm.basepath(Entities.Cores)),
      _filters(Entities.Cores), buildCore _)
  /** EntityCache instance for Kernels. **/
  private val _kernelCache = EntityCache(Set(bpm.basepath(Entities.Kernels)),
      _filters(Entities.Kernels), buildKernel _)
  /** EntityCache instance for Platforms. **/
  private val _platformCache = EntityCache(Set(bpm.basepath(Entities.Platforms)),
      _filters(Entities.Platforms), buildPlatform _)

  /** Internal map of description caches. **/
  private val _caches: Map[Entity, EntityCache[_]] = Map(
    Entities.Architectures    -> _archCache,
    Entities.Compositions     -> _compositionCache,
    Entities.Cores            -> _coreCache,
    Entities.Kernels          -> _kernelCache,
    Entities.Platforms        -> _platformCache
  )

  _caches.values foreach { c => c += _entityCacheListener }

  bpm += new Listener[BasePathManager.Event] {
    def update(e: BasePathManager.Event): Unit = e match {
      case BasePathManager.BasePathChanged(base, path) => _caches(base).clear(Some(Set(path)))
    }
  }

  def dump(osw: java.io.OutputStreamWriter): Unit = {
    import scala.util.Properties.{lineSeparator => NL}

    osw.append("<<_filters>>").append(NL).append(_filters.toString).append(NL)
    _caches foreach { kv =>
      osw.append("<<EntityCache: %s>>".format(kv._1.toString)).append(NL)
      EntityCache.dump(kv._2, osw)
      osw.append(NL)
    }
  }
  /* Internals @} */
}

object EntityManager {
  sealed trait Event
  object Events {
    final case class Changed(entity: Entity, path: Path, kind: Change) extends Event
    final case class Cleared(entity: Entity) extends Event
  }
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
