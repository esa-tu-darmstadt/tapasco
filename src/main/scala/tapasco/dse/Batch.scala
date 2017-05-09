package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers._
import  de.tu_darmstadt.cs.esa.tapasco.base.Configuration
import  java.util.concurrent.CountDownLatch

sealed private trait Batch extends Startable {
  def id: Int
  def runs: Seq[Run]
  def isFirstSuccess: Boolean
  def result: Option[Run]
}

private class ConcreteBatch(val id: Int, val runs: Seq[Run])
                           (implicit exploration: Exploration, configuration: Configuration) extends Batch {
  assert (runs.length > 0, "at least one run must be given per batch")
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def isFirstSuccess: Boolean = runs(0).result map (_.result.equals(ComposeResult.Success)) getOrElse false
  def result: Option[Run] = runs.find(r => r.result map (_.result.equals(ComposeResult.Success)) getOrElse false)

  def start(signal: Option[CountDownLatch] = None): Unit = {
    val done: CountDownLatch = new CountDownLatch(runs.length)
    val elems = runs map (_.element)
    exploration.publish(Exploration.Events.BatchStarted(id, elems))
    _logger.trace("batch {}: starting runs ...", id)
    runs foreach { r =>
      _logger.info("starting [%s] [F=%2.3f] for %s".format(r.element.composition, r.element.frequency, r.target))
      r.start(done)
    }
    _logger.trace("batch {}: awaiting result ...", id)
    done.await()
    _logger.trace("batch {}: finished: result = {}", id, result.toString)
    exploration.publish(Exploration.Events.BatchFinished(id, elems, runs flatMap (_.result)))
    signal foreach (_.countDown())
  }
}

