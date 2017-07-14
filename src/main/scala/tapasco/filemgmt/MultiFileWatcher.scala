package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util._
import scala.collection.mutable.{ArrayBuffer, Map}
import java.nio.file.Path
import java.io.{BufferedReader, FileReader}
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.ConcurrentHashMap
import scala.collection.JavaConverters._

/**
 * MultiFileWatcher monitors the contents of multiple files at once.
 * Content is polled regularly (pollInterval), changes in the content are
 * published as Events (using the [[util.Publisher]] methods).
 * @param pollInterval Polling interval in ms (default: [[MultiFileWatcher.POLL_INTERVAL]]).
 **/
class MultiFileWatcher(pollInterval: Int = MultiFileWatcher.POLL_INTERVAL) extends Publisher {
  type Event = MultiFileWatcher.Event
  import MultiFileWatcher.Events._

  /**
   * Add a file to the monitoring.
   * @param p Path to file to be monitored.
   */
  def +=(p: Path) { open(p) }
  @inline def addPath(p: Path) { this += p }

  /**
   * Add a collection of files to the monitoring.
   * @param ps Collection of Paths to files to be monitored.
   */
  def ++=(ps: Traversable[Path]) { ps foreach (open _) }
  @inline def addPaths(ps: Traversable[Path]) { this ++= ps }

  /**
   * Remove a file from the monitoring.
   * @param p Path to file to be removed.
   */
  def -=(p: Path) { close(p) }
  @inline def remPath(p: Path) { this -= p }

  /**
   * Remove a collection of files from the monitoring.
   * @param ps Collection of Paths to files to be removed.
   */
  def --=(ps: Traversable[Path]): Unit = ps foreach (close _)
  @inline def remPaths(ps: Traversable[Path]) { this --= ps }

  /** Remove and close all files. */
  def closeAll(): Unit = {
    _files.clear
    _waitingFor.synchronized { _waitingFor.clear }
  }

  private[this] var _waitingFor: ArrayBuffer[Path] = ArrayBuffer()

  private def open(p: Path): Boolean = {
    val res = try {
      _files += p -> new BufferedReader(new FileReader(p.toString))
      logger.trace("opened {} successfully", p.toString)
      true
    } catch { case ex: java.io.IOException =>
      logger.trace("could not open {}, will retry ({})", p: Any, ex: Any)
      _waitingFor.synchronized { _waitingFor += p }
      false
    }
    startWatchThread
    res
  }

  private def close(p: Path): Unit = if (_files.contains(p)) {
    _files -= p
  } else if (_waitingFor.contains(p)) {
    _waitingFor.synchronized { _waitingFor -= p }
  }

  private def readFrom(br: BufferedReader, ls: Seq[String] = Seq()): Seq[String] = {
    val line = Option(br.readLine())
    if (line.nonEmpty) readFrom(br, ls :+ line.get) else ls
  }

  private def startWatchThread: Unit = {
    if (_watchThread.get.isEmpty) {
      logger.trace("starting file watch thread ...")
      _watchThread.set(Some(new Thread(new Runnable {
        def run() {
          try {
            while (! _files.isEmpty || ! _waitingFor.isEmpty) {
              val waits = _waitingFor.synchronized { _waitingFor.toList }
              waits foreach { p =>
                logger.trace("waiting for {}", p)
                if (open(p)) _waitingFor.synchronized { _waitingFor -= p }
              }
              val files = _files.toMap
              files foreach { case (p, br) =>
                val lines = readFrom(br)
                if (lines.length > 0) {
                  logger.trace("read {} lines from {}", lines.length, p)
                  publish(LinesAdded(p, lines))
                }
              }
              Thread.sleep(pollInterval)
            }
            _watchThread.set(None)
          } catch { case e: InterruptedException => _watchThread.set(None) }
        }
      })))
      _watchThread.get map (_.start)
    }
  }

  private[this] var _watchThread: AtomicReference[Option[Thread]] = new AtomicReference(None)
  private[this] val _files: Map[Path, BufferedReader] = new ConcurrentHashMap().asScala
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
}

/** MultiFileWatcher companion object. */
object MultiFileWatcher {
  sealed trait Event
  object Events {
    /** Lines ls have been added to file at src. **/
    final case class LinesAdded(src: Path, ls: Traversable[String]) extends Event
  }
  /** Default polling interval for files: once per second. **/
  final val POLL_INTERVAL = 1000 // 1sec
}
