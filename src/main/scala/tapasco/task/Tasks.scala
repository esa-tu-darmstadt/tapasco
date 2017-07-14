package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher
import  scala.collection.JavaConverters._
import  scala.concurrent.Future
import  scala.util.{Failure, Success}
import  scala.concurrent.ExecutionContext.Implicits.global
import  java.util.concurrent.LinkedBlockingQueue
import  java.time.LocalDateTime

/**
 * The Timestamped trait allows to track enqueue, start and completion times:
 * It provides methods to record and query the timestamps for each event.
 * Its primary use is to track the state of [[Task]] instances over time.
 **/
trait Timestamped {
  /** Set timestamp for enqueue to now. **/
  def enqueue(): Unit  = _queued    = Some(LocalDateTime.now())
  /** Set timestamp for start to now. **/
  def start(): Unit    = _started   = Some(LocalDateTime.now())
  /** Set timestamp for completion to now. **/
  def complete(): Unit = _completed = Some(LocalDateTime.now())

  /** Returns timestamp for enqueue (or None, if not enqueued). **/
  def queued: Option[LocalDateTime]    = _queued
  /** Returns timestamp for start (or None, if not started). **/
  def started: Option[LocalDateTime]   = _started
  /** Returns timestamp for completion (or None, if not completed). **/
  def completed: Option[LocalDateTime] = _completed

  private[this] var _queued: Option[LocalDateTime]    = None
  private[this] var _started: Option[LocalDateTime]   = None
  private[this] var _completed: Option[LocalDateTime] = None
}

/**
 * Task is the base trait of schedulable, executable tasks.
 * A task can be run asynchronously and finishes with either success or failure.
 * Concrete tasks may implement more detailed feedback mechanisms to communicate
 * explicit reasons, or deliver result objects.
 * Every task is a [[ResourceConsumer]] and the scheduler may choose to delay
 * tasks for which the resources are not currently available.
 **/
trait Task extends Timestamped with ResourceConsumer {
  /** Textual description of the task. **/
  def description: String
  /** Result of the task (Success == true). **/
  var result: Boolean = false
  /** Definition of the task, will be executed when the task is started. **/
  def job: Boolean
  /** Callback after the task has finished. **/
  def onComplete: Boolean => Unit
  /** Returns true, if the task is currently queued. **/
  def isQueued: Boolean = ! queued.isEmpty
  /** Returns true, if the task is currently running. **/
  def isRunning: Boolean = ! started.isEmpty
  /** Returns true, if the task has run and has finished. **/
  def isCompleted: Boolean = ! completed.isEmpty
}

object Task {
  def taskToString(t: Task): String = Seq(
    "<Task: %s>".format(t.getClass.toString),
    "<<description>>",
    t.description,
    "<<queued>>",
    t.queued.toString,
    "<<started>>",
    t.started.toString,
    "<<completed>>",
    t.completed.toString,
    "<<result>>",
    t.result
  ) mkString (scala.util.Properties.lineSeparator)
}

private class GenericTask(
    val description: String,
    _job: () => Boolean,
    val onComplete: Boolean => Unit) extends Task {
  lazy val job: Boolean = _job()
  val cpus = 0
  val memory = 0
  val licences = Map[String, Int]()
}

class Tasks extends Publisher {
  type Event = Tasks.Event
  import Tasks.Events._
  private[this] final val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  override def +=(el: EventListener): Unit = {
    super.+=(el)
    el.update(TaskCleared(this))
  }


  private[this] val _rm = ResourceMonitor()
  def resourceStatus: String = _rm.status

  def queued: Seq[Task] = _queued.asScala.toSeq
  def running: Seq[Task] = _running.asScala.toSeq
  def complete: Seq[Task] = _complete.asScala.toSeq

  def stop(): Unit = {
    _stop = true
    if (processingThread.isAlive()) processingThread.interrupt()
  }
  private[this] var _stop = false

  private val _queued = new LinkedBlockingQueue[Task]()
  private val _running = new LinkedBlockingQueue[Task]()
  private val _complete = new LinkedBlockingQueue[Task]()

  def apply(description: String, job: () => Boolean, onComplete: Boolean => Unit): Task = {
    _logger.debug("enqueing new generic task (%s)".format(description))
    val t = new GenericTask(description, job, onComplete)
    _queued.put(t)
    t.enqueue()
    publish(TaskQueued(this, t))
    t
  }

  def apply(t: Task): Unit = {
    _logger.debug("enqueing new task (%s)".format(t.toString))
    _queued.put(t)
    t.enqueue()
    publish(TaskQueued(this, t))
  }

  def clearCompleted(): Unit = {
    _complete.clear()
    publish(TaskCleared(this))
  }

  private[this] def completeTask(t: Task) = {
    t.complete()
    _running.remove(t)
    _rm.didFinish(t)
    _complete.put(t)
    t.onComplete(t.result)
    publish(TaskCompleted(this, t))
  }

  private class ProcessingRunnable(tasks: Tasks) extends Runnable {
    def run() {
      try {
        while (! _stop) {
          val t: Task = _queued.take()
          if (_rm.canStart(t)) {
            _logger.debug("starting job {}", t.toString)
            t.start()
            _running.put(t)
            _rm.doStart(t)
            publish(TaskStarted(tasks, t))

            val f = Future { t.result = t.job; t.result } onComplete {
              case Success(r) => completeTask(t)
              case Failure(e) => { t.result = false; completeTask(t) }
            }
            Thread.sleep(Tasks.SCHEDULER_SLEEP_MS)
          } else {
            _logger.trace("cannot launch job {}, re-inserting into queue", t.toString)
            // re-insert
            _queued.put(t)
          }
        }
      } catch { case e: InterruptedException => _logger.debug("Tasks queue threads was interrupted") }
    }
  }

  private val processingThread = new Thread(new ProcessingRunnable(this))

  processingThread.start
}

object Tasks {
  sealed trait Event { def source: Tasks }
  final object Events {
    final case class TaskQueued(source: Tasks, t: Task) extends Event
    final case class TaskStarted(source: Tasks, t: Task) extends Event
    final case class TaskCompleted(source: Tasks, t: Task) extends Event
    final case class TaskCleared(source: Tasks) extends Event
  }

  def dump(t: Tasks, osw: java.io.OutputStreamWriter): Unit = {
    val NL = scala.util.Properties.lineSeparator
    osw
      .append("<Tasks>").append(NL)
      .append("<<_queued>>").append(NL).append(t._queued.asScala map (Task.taskToString _) mkString (NL)).append(NL)
      .append("<<_running>>").append(NL).append(t._running.asScala map (Task.taskToString _) mkString (NL)).append(NL)
      .append("<<_complete>>").append(NL).append(t._complete.asScala map (Task.taskToString _) mkString (NL)).append(NL)
      .append("<<_rm>>").append(NL).append(t.resourceStatus).append(NL)
      .append(NL)
  }

  /** Grace period after a task was launched, default: 250ms. */
  private final val SCHEDULER_SLEEP_MS = 250
}
