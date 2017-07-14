package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file.{Path, Paths}

// TODO do not use singleton for FileAssetManager

/**
 * FileAssetManager is a singleton that manages TPC entities:
 * It manages the base paths in which to look for description files
 * for each of the entity kinds and monitors them for changes.
 * For each entity kind it provides a EntityCache, which can
 * be used to get both paths to the description files, as well as
 * instantiated, cached instances of Description for them.
 *
 * This is the central class managing dynamically defined
 * Descriptions in TPC and should be used to access Descriptions
 * objects everywhere for Performance. Do not use the Builders
 * directly.
 **/
final object FileAssetManager extends Publisher {
  private val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /* @{ Event trait hierarchy */
  sealed trait Event
  final object Events {
    final case class EntityChanged(entity: Entity, path: Path, kind: Change) extends Event
    final case class EntitiesCleared(entity: Entity) extends Event
    final case object ReportsCleared extends Event
    final case class ReportChanged(path: Path, kind: Change) extends Event
    final case class BasePathChanged(base: Entity, path: Path) extends Event
  }
  /* @} */

  /* @{ default directories */
  /** Base directory of TPC, set by TAPASCO_HOME environmment variable. **/
  lazy val TAPASCO_HOME = try   { Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath().normalize }
                          catch { case e: NoSuchElementException =>
                              _logger.error("FATAL: TAPASCO_HOME environment variable is not set")
                              throw e }
  /* @} */

  def apply(cfg: Configuration): Unit = {
    archDir = cfg.archDir
    compositionDir = cfg.compositionDir
    coreDir = cfg.coreDir
    kernelDir = cfg.kernelDir
    platformDir = cfg.platformDir
  }

  /**
   * Clears and resets all caches.
   */
  def reset(): Unit = this.synchronized {
    //_caches.values foreach { _.clear() }
    entities.reset()
    reports.reset()
  }

  /** Start or restart the directory monitoring. **/
  def start(): Unit = _watcher.start()

  /** Stop the directory monitoring. **/
  def stop(): Unit = _watcher.stop()

  /**
   * Returns the output directory for given Core and Target.
   * @param core Core instance.
   * @param target Target instance.
   * @return Output directory in which files should reside.
   **/
  def outputDir(core: Core, target: Target): Path =
    coreDir.resolve(core.name).resolve(target.ad.name).resolve(target.pd.name)

  def targetForReport(f: Path): Target = {
    val subpath = f.subpath(basepath(Entities.Cores).getNameCount(), basepath(Entities.Cores).getNameCount() + 3)
    _logger.trace("subpath = {}", subpath)
    val (kernel, arch, platform) = (subpath.getName(0), subpath.getName(1), subpath.getName(2))
    _logger.trace("kernel = {}, arch = {}, platform = {}", kernel, arch, platform)
    Target(FileAssetManager.entities.architectures filter { _.name.equals(arch.toString) } head,
      FileAssetManager.entities.platforms filter { _.name.equals(platform.toString) } head)
  }

  /* @{ base path accessors */
  private val bpm = new BasePathManager

  val basepath: Map[Entity, BasePath] = {
    bpm += new Listener[BasePathManager.Event] {
      def update(e: BasePathManager.Event): Unit = e match {
        case BasePathManager.BasePathChanged(base, path) =>
          _dirs.synchronized { _dirs += base -> path }
          if (e equals Entities.Cores) reports.clear(Some(Set(path)))
          restartWatcher()
          publish(Events.BasePathChanged(base, path))
      }
    }
    bpm
  }

  /** Returns the current base path for Architectures. **/
  def archDir: Path = basepath(Entities.Architectures)
  /** Sets the current base path for Architectures. **/
  def archDir_=(p: Path): Unit = basepath(Entities.Architectures).set(p)
  /** Returns the current base path for Cores. **/
  def coreDir: Path = basepath(Entities.Cores)
  /** Sets the current base path for Cores. **/
  def coreDir_=(p: Path): Unit = basepath(Entities.Cores).set(p)
  /** Returns the current base path for Compositions. **/
  def compositionDir: Path = basepath(Entities.Compositions)
  /** Sets the current base path for Compositions. **/
  def compositionDir_=(p: Path): Unit = basepath(Entities.Compositions).set(p)
  /** Returns the current base path for Kernels. **/
  def kernelDir: Path = basepath(Entities.Kernels)
  /** Sets the current base path for Kernels. **/
  def kernelDir_=(p: Path): Unit = basepath(Entities.Kernels).set(p)
  /** Returns the current base path for Platforms. **/
  def platformDir: Path = basepath(Entities.Platforms)
  /** Sets the current base path for Platforms. **/
  def platformDir_=(p: Path): Unit = basepath(Entities.Platforms).set(p)
  /* @} */

  /* @{ Entity management */
  private val _entityListener = new Listener[EntityManager.Event] {
    def update(e: EntityManager.Event): Unit = e match {
      case EntityManager.Events.Changed(ent, p, k) => publish(Events.EntityChanged(ent, p, k))
      case EntityManager.Events.Cleared(ent)       => publish(Events.EntitiesCleared(ent))
    }
  }
  val entities = new EntityManager(bpm) { this += _entityListener }
  /* @} */

  /* @{ Report management */
  private val _reportListener = new Listener[EntityCache.Event] {
    def update(e: EntityCache.Event): Unit = e match {
      case EntityCache.Events.Changed(ec, p, k) =>
        _logger.trace("received Changed({}, {}, {})", ec, p, k)
        publish(FileAssetManager.Events.ReportChanged(p, k))
      case EntityCache.Events.Cleared(ec, nps) =>
        _logger.trace("received Cleared({}, {})", ec:Any, nps:Any)
        publish(FileAssetManager.Events.ReportsCleared)
    }
  }
  val reports = new ReportManager(basepath(Entities.Cores).get) { this += _reportListener }
  /* @} */

  /* @{ internals */
  /** Internal map of base paths. **/
  private val _dirs: scala.collection.mutable.Map[Entity, Path] =
    scala.collection.mutable.Map(BasePathManager.defaultDirectory.toSeq map (e => (e._1, e._2._1)): _*)

  private def startWatcher(): DirectoryWatcher = _dirs.synchronized {
    val w = DirectoryWatcher(_dirs.values.toSeq: _*)
    w.start()
    w += entities.directoryListener
    w += reports.directoryListener
    w
  }

  private def restartWatcher(): Unit = _watcher.synchronized {
    _watcher.stop()
    _watcher -= entities.directoryListener
    _watcher -= reports.directoryListener
    _watcher = startWatcher()
  }

  private var _watcher = startWatcher()

  def dump(osw: java.io.OutputStreamWriter): Unit = {
    val NL = scala.util.Properties.lineSeparator
    osw
      .append("<FileAssetManager>").append(NL)
      .append("<<_dirs>>").append(NL).append(_dirs.toString).append(NL)
    entities.dump(osw)
    reports.dump(osw)
  }
  /* @} */
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
