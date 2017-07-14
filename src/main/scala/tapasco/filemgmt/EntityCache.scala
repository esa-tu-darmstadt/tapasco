package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.util.matching.Regex
import  java.nio.file._

/**
 * EntityCache monitors description files and keeps cached versions
 * of the corresponding entities, as long as memory permits.
 * @param T subclass of Description
 **/
trait EntityCache[T] extends Listener[DirectoryWatcher.Event] with Publisher {
  type Event = EntityCache.Event
  /** Regular expression to match description files with. **/
  def filter: Regex
  /** Set of matching files (updated automatically). **/
  def files: Set[Path]
  /** Set of entities (updated automatically). **/
  def entities: Set[T]
  /** Build description from path. **/
  def apply(path: Path*): Seq[Option[T]]
  /** Clear cache and refill from given paths (optional). **/
  def clear(paths: Option[Set[Path]] = None): Unit
}

/**
 * DefaultEntityCache: Standard implementation that uses DirectoryWatcher.
 * DirectoryWatcher is used to monitor the directory, build function is memoized
 * and automatically updated, if description files are modified or deleted.
 **/
private class DefaultEntityCache[T](paths: Set[Path], val filter: Regex, build: Path => Option[T]) extends EntityCache[T] {
  import scala.collection.mutable.{Set => MSet}
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private val _files: MSet[Path] = findFiles(paths)

  /** Finds all matching files via file tree walk. **/
  private def findFiles(paths: Set[Path]): MSet[Path] = {
    val visitor = new SimpleFileVisitor[Path] {
      val files: MSet[Path] = MSet()
      override def visitFile(file: Path, attr: java.nio.file.attribute.BasicFileAttributes) = {
        filter.findFirstIn(file.toString) foreach { _ => files += file.toAbsolutePath }
        FileVisitResult.CONTINUE
      }
    }
    (paths map { d =>
      try   { Files.walkFileTree(d.toAbsolutePath, visitor); visitor.files }
      catch { case ex: java.io.IOException => MSet[Path]() }
    } fold MSet()) (_ ++ _)
  }

  private def isInPaths(p: Path): Boolean =
    (paths map { p => p.toAbsolutePath().normalize().startsWith(p) } fold false)(_ || _)

  private def doubleCheckPath(p: Path): Unit = if (p.toFile.isDirectory && isInPaths(p)) {
    val newFiles = findFiles(Set(p)) filterNot (_files contains _)
    if (newFiles.size > 0) {
      _logger.trace("found new files: {}", newFiles)
      _files ++= newFiles
      newFiles foreach { file => publish(EntityCache.Events.Changed(this, file, Changes.Create)) }
    }
  }

  /** DirectoryWatcher events: used to invalidate cache. **/
  def update(e: DirectoryWatcher.Event): Unit = {
    import DirectoryWatcher.Events._
    // FIXME is the double check really necessary?
    e match {
      case Create(p) => doubleCheckPath(p)
      case Modify(p) => doubleCheckPath(p)
      case _ => {}
    }
    filter.findFirstIn(e.path.toAbsolutePath().normalize().toString()) foreach { _ =>
      _logger.trace("e = {}", e)
      e match {
        // add to running tally of matching files
        case Create(p) => {
          _files += p.toAbsolutePath().normalize()
          _build.remove(p)
          publish(EntityCache.Events.Changed(this, p, Changes.Create))
        }
        // remove from matching files and cache
        case Delete(p) => {
          _files -= p.toAbsolutePath().normalize()
          _build.remove(p)
          publish(EntityCache.Events.Changed(this, p, Changes.Delete))
        }
        // invalidate cache (do not re-build automatically)
        case Modify(p) => {
          _files += p.toAbsolutePath().normalize()
          _build.remove(p)
          publish(EntityCache.Events.Changed(this, p, Changes.Modify))
        }
      }
    }
  }

  /** @inheritdoc **/
  def files: Set[Path] = _files.toSet

  /** @inheritdoc **/
  def entities: Set[T] = files map (_build) flatten

  /** @inheritdoc **/
  def apply(files: Path*): Seq[Option[T]] = files map (_build)

  /** @inheritdoc **/
  def clear(paths: Option[Set[Path]] = None): Unit = {
    val newpaths: Option[Set[Path]] = if (paths.isEmpty) Some(this.paths) else paths
    _files.clear()
    newpaths foreach { ps => _files ++= findFiles(ps) }
    _build.clear()
    publish(EntityCache.Events.Cleared(this, newpaths))
  }

  /** Memoization of build function. **/
  private val _build = new Memoization[Path, Option[T]](build)
}

/** Factory for EntityCaches. **/
object EntityCache {
  /* @{ Event trait hierarchy */
  sealed trait Event
  final object Events {
    final case class Changed[T](origin: EntityCache[T], path: Path, kind: Change) extends Event
    final case class Cleared[T](origin: EntityCache[T], newPaths: Option[Set[Path]]) extends Event
  }
  /* @} */

  /**
   * Retrieve a EntityCache for type T using a default path, a regular
   * expression to match file names of source files and a builder function.
   * @param T subclass of Description to build/cache.
   * @param paths paths to search initially
   * @param filter regular expression to match files with.
   * @param build builder function used to build Descriptions from files.
   * @return EntityCache for T
   **/
  def apply[T](paths: Set[Path], filter: Regex, build: Path => Option[T]): EntityCache[T] =
    new DefaultEntityCache[T](paths, filter, build)

  def dump[T](c:  EntityCache[T], osw: java.io.OutputStreamWriter): Unit =
    DefaultEntityCache.dump(c.asInstanceOf[DefaultEntityCache[T]], osw)
}

private[filemgmt] object DefaultEntityCache {
  def dump[T](c:  DefaultEntityCache[T], osw: java.io.OutputStreamWriter): Unit = {
    val NL = scala.util.Properties.lineSeparator
    osw
      .append("<DefaultEntityCache>").append(NL)
      .append("<<_files>>").append(c._files map (_.toString) mkString (NL)).append(NL)
      .append("<<_build>>")
    Memoization.dump(c._build, osw)
    osw.append(NL)
  }
}
