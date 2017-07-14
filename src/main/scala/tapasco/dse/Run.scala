package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers._
import  java.util.concurrent.CountDownLatch

sealed private trait Run extends Startable with Ordered[Run] {
  import scala.math.Ordered.orderingToOrdered
  def element: DesignSpace.Element
  def target: Target
  def result: Option[Composer.Result]
  def task: Option[ComposeTask]
  def area: AreaEstimate
  def compare(that: Run): Int =
    (this.area.utilization, this.element.h, this.element.frequency) compare
    (that.area.utilization, that.element.h, that.element.frequency)
}

private class ConcreteRun(val no: Int, val element: DesignSpace.Element, val target: Target, val debugMode: Option[String])
                         (implicit exploration: Exploration, configuration: Configuration) extends Run {
  private[this] var _result: Option[Composer.Result] = None
  private[this] var _task: Option[ComposeTask] = None
  lazy val area = AreaUtilization(target, element.composition) getOrElse {
    throw new Exception("could not get area estimation for %s".format(element))
  }

  def result: Option[Composer.Result] = _result
  def task: Option[ComposeTask] = _task

  def start(signal: Option[CountDownLatch]): Unit = {
    val id = "%05d".format(no)
    implicit val maxThreads: Option[Int] = Some(1) // limit number of threads in DSE to control load
    val t = new ComposeTask(
      composition     = element.composition,
      designFrequency = element.frequency,
      implementation  = Composer.Implementation.Vivado,   // FIXME use Implementation to determine composer
      target          = target,
      logFile         = Some("%s/%s/%s.log".format(exploration.basePath, id, id)),
      debugMode       = debugMode,
      onComplete      = res => stop(signal))
    _task = Some(t)
    exploration.publish(Exploration.Events.RunStarted(element, t))
    exploration.tasks(t) // start task
  }

  private def stop(signal: Option[CountDownLatch]): Unit = {
    assert (! task.isEmpty, "stop() must not be called with empty task")
    _result = _task.get.composerResult
    signal foreach (_.countDown())
    exploration.publish(Exploration.Events.RunFinished(element, task.get))
  }
}

