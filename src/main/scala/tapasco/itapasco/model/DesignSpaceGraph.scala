package de.tu_darmstadt.cs.esa.tapasco.itapasco.model
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.dse.Exploration
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.util.LogFormatter._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.Composer
import  de.tu_darmstadt.cs.esa.tapasco.dse.DesignSpace
import  scala.collection.JavaConverters._
import  edu.uci.ics.jung.graph._
import  scala.collection.mutable.Map
import  Exploration._
import  DesignSpaceGraph._

/**
 * A graph model of the design space based on DirectedSparseMultigraph.
 * Elements a the [[de.tu_darmstadt.cs.esa.tapasco.dse.DesignSpace.Element]]
 * instances and/or their corresponding Run instances, which can provide
 * additional information about already explored parts of the design space (e.g., kind
 * of error, if any, or WNS).
 * Edges indicate containment in the same batch, pruning relations (i.e., Runs that
 * have been pruned due to the result of another Run) or generating relations (i.e.,
 * Runs that have not been in the initial set, but were generated due to the result of
 * another Run).
 **/
class DesignSpaceGraph extends DirectedSparseMultigraph[N, E] with Listener[Exploration.Event] {
  import DesignSpaceGraph.Edges._, DesignSpaceGraph.RunStates._
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] var _hrange: (Double, Double) = (Double.PositiveInfinity, Double.NegativeInfinity)
  private[this] val _runState: Map[DesignSpace.Element, RunState]                 = Map()
  private[this] val _results: Map[DesignSpace.Element, Composer.Result]           = Map()
  private[this] val _generatedFrom: Map[DesignSpace.Element, DesignSpace.Element] = Map()
  private[this] val _utilization: Map[DesignSpace.Element, AreaEstimate]          = Map()

  def hrange: (Double, Double) = _hrange
  def state(e: DesignSpace.Element): Option[RunState]                    = _runState get e
  def result(e: DesignSpace.Element): Option[Composer.Result]            = _results get e
  def generatedFrom(e: DesignSpace.Element): Option[DesignSpace.Element] = _generatedFrom get e
  def utilization(e: DesignSpace.Element): Option[AreaEstimate]          =
    AreaUtilization(Job.job.target, e.composition)(Config.configuration)

  def load(filename: String) {
    clear()
    ExplorationLog += this
    ExplorationLog.fromFile(filename) foreach { case (_, l) => ExplorationLog.replay(l) }
    ExplorationLog -= this
  }

  def clear(): Unit = this.synchronized {
    _logger.debug("clearing DesignSpaceGraph")
    _hrange = (Double.PositiveInfinity, Double.NegativeInfinity)
    _runState.clear()
    _results.clear()
    _generatedFrom.clear()
    _utilization.clear()
  }

  def nextInBatch(e: DesignSpace.Element): Option[DesignSpace.Element] =
    getOutEdges(e).asScala collectFirst { case InBatch(_, _, to) => to }
  def prevInBatch(e: DesignSpace.Element): Option[DesignSpace.Element] =
    getInEdges(e).asScala collectFirst { case InBatch(_, from, _) => from }
  def generatees(e: DesignSpace.Element): Seq[DesignSpace.Element] =
    getOutEdges(e).asScala collect { case GeneratedBy(_, to) => to } toSeq
  def generators(e: DesignSpace.Element): Seq[DesignSpace.Element] =
    getInEdges(e).asScala collect { case GeneratedBy(from, _) => from } toSeq
  def prunees(e: DesignSpace.Element): Seq[DesignSpace.Element] =
    getOutEdges(e).asScala collect { case PrunedBy(_, _, to) => to } toSeq
  def pruners(e: DesignSpace.Element): Seq[DesignSpace.Element] =
    getInEdges(e).asScala collect { case PrunedBy(_, from, _) => from } toSeq

  // scalastyle:off cyclomatic.complexity
  def update(e: Event): Unit = this.synchronized { _logger.trace("e = {}", e); e match {
    case Events.ExplorationStarted(_) =>
      _runState.clear()
      _utilization.clear()
      _generatedFrom.clear()
      edges.clear()
      vertices.clear()
    case Events.RunDefined(element, utilization) =>
      _hrange = (Seq(element.h, _hrange._1).min, Seq(element.h, _hrange._2).max)
      _utilization += element -> utilization
      //addVertex(element)
    case Events.RunGenerated(from, element, utilization) =>
      _logger.trace("generated {} from {}", from: Any, element)
      _hrange = (Seq(element.h, _hrange._1).min, Seq(element.h, _hrange._2).max)
      _utilization += element -> utilization
      _generatedFrom += element -> from
      addVertex(element)
      assert (vertices.keySet() contains from, "source element %s must be in vertices".format(from))
      assert (vertices.keySet() contains element, "generated element must be in vertices")
      addEdge(GeneratedBy(from, element), from, element)
    case Events.RunStarted(element, _) =>
      _logger.trace("adding element {}", element)
      addVertex(element)
      _runState += element -> Running
    case Events.RunFinished(element, task) =>
      _runState += element -> Finished
    case Events.RunPruned(elements, cause, reason) =>
      assert (vertices.keySet() contains cause, "_vertices must contain causing element")
      elements foreach { element =>
        addVertex(element)
        _runState += element -> Pruned
        addEdge(PrunedBy(reason, cause, element), cause, element)
      }
      //assert (vertices.keySet() contains element, "_vertices must contain pruned element")
      //addEdge(PrunedBy(reason, cause, element), cause, element)
    case Events.BatchStarted(id, elements) =>
      _logger.debug("batch {} started", id)
      _logger.trace("batch {}: elements = {}", id, elements map (e => logformat(e)) mkString " ")
      //elements foreach { addVertex _ }
      if (elements.length > 1) {
        elements zip elements.tail foreach { case (from, to) =>
          addEdge(InBatch(id, from, to), from, to)
          _logger.trace("connecting {} to {}", logformat(from): Any, logformat(to): Any)
        }
      }
    case Events.BatchFinished(id, elements, results) =>
      _results ++= elements zip results
      //edges.clear()
    case _ => _logger.debug("received event: {}", e.toString)
  }}
  // scalastyle:on cyclomatic.complexity
}

/** DesignSpaceGraph companion object: basic types. */
object DesignSpaceGraph {
  /** Node type: [[de.tu_darmstadt.cs.esa.tapasco.dse.DesignSpace.Element]]. */
  type N = DesignSpace.Element

  /** Edge type: [[Edges.InBatch]], [[Edges.PrunedBy]] or [[Edges.GeneratedBy]]. */
  sealed trait E
  /** Singleton containing all instances of [[E]]. */
  final object Edges {
    /** Indicates that to follows from in batch id. */
    final case class InBatch(id: Int, from: DesignSpace.Element, to: DesignSpace.Element) extends E
    /** Indicates that to was pruned due to the result of from for reason. */
    final case class PrunedBy(reason: PruningReason, from: DesignSpace.Element, to: DesignSpace.Element) extends E
    /** Indicates that to was generated due to the result of from (timing failure). */
    final case class GeneratedBy(from: DesignSpace.Element, to: DesignSpace.Element) extends E
  }

  /** Type for state of Runs: [[RunStates.Running]], [[RunStates.Finished]] or [[RunStates.Pruned]]. */
  sealed trait RunState

  /** Singleton containing all instances of [[RunState]]. */
  final object RunStates {
    /** Indicates that the Run is currently being executed. */
    final case object Running extends RunState
    /** Indicates that the Run has been executed. */
    final case object Finished extends RunState
    /** Indicates that the Run is pruned and will not be executed. */
    final case object Pruned extends RunState
  }
}
