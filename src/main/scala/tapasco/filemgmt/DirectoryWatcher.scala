package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher
import  java.nio.file._
import  java.nio.file.StandardWatchEventKinds._
import  java.util.concurrent.atomic.AtomicReference
import  scala.collection.JavaConverters._
import  scala.util.control.Exception._
import  java.time.{Instant, LocalDateTime, ZoneOffset}
import  java.nio.file.attribute.BasicFileAttributes

/**
 * DirectoryWatcher: Publishes events on changes in directory.
 * Must be started and stopped manually with the corresponding
 * methods; will spawn background thread to receive file events.
 **/
sealed trait DirectoryWatcher extends Publisher {
  /** @inheritdoc **/
  type Event = DirectoryWatcher.Event
  /** Paths that are being monitored. **/
  def paths: Set[Path]
  /** Starts the monitoring. **/
  def start(): Boolean
  /** Stops the monitoring. **/
  def stop(): Unit
}

/**
 * Default implementation for DirectoryWatcher:
 * Uses JDK 7+ WatchService to monitor directory.
 * @param paths Paths to monitor.
 **/
private class DefaultDirectoryWatcher(val paths: Set[Path]) extends DirectoryWatcher {
  import scala.collection.mutable.Map
  import DirectoryWatcher.Events._
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _ws = FileSystems.getDefault().newWatchService()
  private[this] val _wk: Map[Path, WatchKey] = Map()
  private[this] var _watchThread: AtomicReference[Option[Thread]] = new AtomicReference(None)

  /** @inheritdoc **/
  def start(): Boolean = start(paths)

  /**
   * Walks the directory trees found at the given paths, generating create and
   * modify events for each file/directory that has been created/modified after
   * the given timestamp. Recursively starts watching the paths found.
   * @param ps Set of paths to walk.
   * @param ts Timestamp to compare file attributes against for event generation.
   *           (Default: 5secs ago, UTC)
   **/
  private def start(ps: Set[Path], ts: LocalDateTime = LocalDateTime.ofInstant(Instant.now(),
      ZoneOffset.UTC).minusSeconds(DirectoryWatcher.TIME_WINDOW_SECS)): Boolean = {
    val logger = _logger
    logger.trace("walking {} with {}", ps: Any, ts)
    val visitor = new SimpleFileVisitor[Path] {
      private def checkPath(p: Path, bfa: BasicFileAttributes): Unit = {
        val created = LocalDateTime.ofInstant(bfa.creationTime().toInstant(), ZoneOffset.UTC)
        if (created.isAfter(ts)) {
          logger.trace("walk:generating Create event for {}", p)
          publish(Create(p))
        } else {
          logger.trace("walk:created: {}, ts: {}", created: Any, ts)
        }
        val modified = LocalDateTime.ofInstant(bfa.lastModifiedTime().toInstant(), ZoneOffset.UTC)
        if (modified.isAfter(ts)) {
          logger.trace("walk:generating Modified event for {}", p)
          publish(Modify(p))
        } else {
          logger.trace("walk:modified: {}, ts: {}", modified: Any, ts)
        }
      }
      override def preVisitDirectory(dir: Path, bfa: BasicFileAttributes) = {
        logger.trace("walk:preVisitDirectory {}", dir)
        startWatching(dir)
        checkPath(dir, bfa)
        FileVisitResult.CONTINUE
      }
      override def visitFile(f: Path, bfa: BasicFileAttributes) = {
        logger.trace("visitFile {}", f)
        checkPath(f, bfa)
        FileVisitResult.CONTINUE
      }
    }
    ps filter { p => p.toAbsolutePath.toFile.exists() } foreach { path =>
      try { Files.walkFileTree(path.toAbsolutePath, visitor) }
      catch { case e: FileSystemException => _logger.debug("could not walk directory: {}", e) }
    }
    if (ps equals paths) startWatchThread() else true
  }

  /** @inheritdoc **/
  def stop(): Unit = _wk.synchronized {
    _logger.debug("stopping directory watcher ...")
    _wk.values foreach { _.cancel() }
    _wk.clear()
    _watchThread.getAndSet(None) foreach { t: Thread =>
      t.interrupt()
      _logger.debug("watch thread interrupted")
    }
    _logger.debug("directory watcher stopped.")
  }

  /**
   * Adds given path to monitoring list.
   * @param path Path to monitor.
   * @return true, if successful, false otherwise.
   **/
  private def startWatching(path: Path): Boolean = try {
    _wk.synchronized { if (! _wk.contains(path)) {
      _logger.trace("starting to watch {}", path)
      val wk = path.register(_ws, ENTRY_CREATE, ENTRY_DELETE, ENTRY_MODIFY, OVERFLOW)
      _wk += path -> wk
    }}
    true
  } catch { case ioex: java.io.IOException =>
    _logger.debug("Could not watch %s: %s".format(path.toString, ioex.toString))
    false
  }

  /**
   * Starts the internal watch thread:
   * Waits for WatchService events in blocking mode, publishes corresponding events.
   **/
  private def startWatchThread(): Boolean = {
    val started = _watchThread.weakCompareAndSet(None, {
      _logger.trace("starting watchkey thread for {} ...", paths)
      Some(new Thread(new WatchThread))
    })
    // if watchThread was newly set, start its execution
    if (started) _watchThread.get foreach { _.start }
    started
  }

  private class WatchThread extends Runnable {
    def run() {
      try {
        // watch until interrupted
        while(_watchThread.get map (_ == Thread.currentThread()) getOrElse false) {
          // get the next key (blocks if none available)
          val watchKey = _ws.take()

          // retrieve and process the events
          watchKey.pollEvents().asScala foreach { processEvent(watchKey, _) }

          // reset the key; remove inaccessible directories from monitor list
          if (! watchKey.reset()) {
            _wk.synchronized {
              _wk.find(kv => kv._2.equals(watchKey)) foreach { kv =>
                _logger.debug("directory {} is inaccessible, watching stopped", kv._1)
                _wk remove kv._1
              }
            }
          }
        }
      } catch {
        case e: InterruptedException =>  // abort watch thread
          _logger.debug("watchkey thread for {} was interrupted", paths)
          //_watchThread.set(None)
        case c: ClosedWatchServiceException =>
          _logger.debug("watch service for {} was closed", paths)
      }
    }

    private def processEvent(watchKey: WatchKey, event: WatchEvent[_]): Unit = event.kind match {
      case OVERFLOW => { // TODO check: is this sufficient?
        _logger.warn("received OVERFLOW warning, resetting")
      } // do nothing
      case _ =>
        // get full path of event file
        val fp = allCatch.opt(watchKey.watchable.asInstanceOf[Path].resolve(
            event.asInstanceOf[WatchEvent[Path]].context))
        if (fp.isEmpty) {
          _logger.warn("could not retrieve full path for event %s of kind %s for watchable %s [%s]"
              .format(event.toString, event.kind.toString, watchKey.watchable.toString,
                watchKey.watchable.getClass.toString))
        } else {
          _logger.trace("event {} for {} received", event.kind: Any, fp.get)
          // if event was creation of new directory: add it to monitor list
           if (event.kind == ENTRY_CREATE && fp.get.toFile().isDirectory()) {
             start(Set(fp.get))
           }
           // publish event
           publish(mkEvent(event.kind)(fp.get))
        }
    }
  }

  /** Helper: Translates event kind to constructor call. **/
  private def mkEvent(kind: WatchEvent.Kind[_]): Path => Event = kind match {
    case ENTRY_CREATE => Create.apply _
    case ENTRY_MODIFY => Modify.apply _
    case ENTRY_DELETE => Delete.apply _
  }
}

/**
 * DirectoryWatcher companion object:
 * Contains event definitions and factory method.
 **/
object DirectoryWatcher {
  /** Event type. **/
  sealed trait Event { def path: Path }
  /** Events. **/
  final object Events {
    /** Path was created. **/
    final case class Create(path: Path) extends Event
    /** Path was modified. **/
    final case class Modify(path: Path) extends Event
    /** Path was deleted. **/
    final case class Delete(path: Path) extends Event
  }

  /**
   * DirectoryWatcher factory method.
   * @param paths Sequence of paths to monitor.
   **/
  def apply(paths: Path*): DirectoryWatcher = {
    require (paths.length > 0, "must give at least one path to watch")
    new DefaultDirectoryWatcher(Set(paths: _*))
  }

  /** Time window size for newly created files: 5 secs */
  final val TIME_WINDOW_SECS = 5
}
