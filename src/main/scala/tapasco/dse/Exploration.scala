package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.{Composer, ComposeResult}
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.collection.mutable.PriorityQueue
import  Exploration.PruningReason
import  Exploration.PruningReasons._
import  java.nio.file._

trait Exploration extends Publisher {
  type Event = Exploration.Event
  def initialComposition: Composition
  def target: Target
  def designFrequency: Heuristics.Frequency
  def dimensions: DesignSpace.Dimensions
  def space: DesignSpace
  def batchSize: Int
  def tasks: Tasks      // TODO why is this necessary?
  def configuration: Configuration
  def start(): Option[(DesignSpace.Element, Composer.Result, Task)]
  def result: Option[(DesignSpace.Element, Composer.Result)]
  def basePath: Path
  def debugMode: Option[String]
}

private class ConcreteExploration(
    val initialComposition: Composition,
    val target: Target,
    val dimensions: DesignSpace.Dimensions,
    val designFrequency: Heuristics.Frequency,
    val batchSize: Int = Exploration.MAX_BATCH_SZ,
    val basePath: Path,
    val debugMode: Option[String])(implicit cfg: Configuration, val tasks: Tasks) extends Exploration {
  private implicit val _exploration = this
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private var _result: Option[(DesignSpace.Element, Composer.Result)] = None
  private[this] final val _nextRunId = new java.util.concurrent.atomic.AtomicInteger
  private def nextRunId: Int = _nextRunId.getAndIncrement()
  def result: Option[(DesignSpace.Element, Composer.Result)] = _result
  val space = new DesignSpace(initialComposition, target, Heuristics.ThroughputHeuristic,
    dimensions, designFrequency)

  private def createBatch(q: PriorityQueue[Run], batchNumber: Int): Batch = {
    val batch = new ConcreteBatch(batchNumber, 0 until Seq(batchSize, q.length).min map { _ =>  q.dequeue })
    _logger.info("current batch: {} [{}]", batch.id, batch.runs.length)
    batch
  }

  protected def prune(q: PriorityQueue[Run], run: Run): Seq[(Run, PruningReason)] = {
    import ComposeResult._
    lazy val util = AreaUtilization(run.target, run.element.composition)
    def hasSameCompo(r: Run)  = r.element.composition.equals(run.element.composition)
    def hasHigherFreq(r: Run) = r.element.frequency >= run.element.frequency
    def hasHigherUtil(r: Run) = AreaUtilization(r.target, r.element.composition) >= util
    def hasLowerH(r: Run)     = r.element.h < run.element.h

    _logger.debug("number of elements with same composition: {}", q filter (r => hasSameCompo(r)) length)
    _logger.debug("number of elements with same composition and higher freq: {}",
      q filter (r => hasSameCompo(r) && hasHigherFreq(r)) length)
    _logger.debug("number of elements with higher util: {}", q filter (r => hasHigherUtil(r)) length)
    _logger.debug("number of elements with lower H: {}", q filter (r => hasLowerH(r)) length)

    val prunees: Seq[Run] = run.result map (_.result match {
      case Success       => q.toSeq filter (hasLowerH _)
      case PlacerError   => q.toSeq filter (hasHigherUtil _)
      case TimingFailure => q.toSeq filter (r => hasSameCompo(r) && hasHigherFreq(r))
      case _ => Seq()
    }) getOrElse Seq()

    val reason = run.result map (_.result match {
      case Success       => WorseThanPrune
      case PlacerError   => AreaPrune
      case _             => FrequencyPrune
    }) getOrElse FrequencyPrune

    prunees map { p => (p, reason) }
  }

  protected def generate(ds: DesignSpace, run: Run): Seq[Run] = {
    assert(! run.result.isEmpty, "must not pass non-finished Runs to generate")
    // generate feedback elements for timing failures
    if (run.result.nonEmpty && run.result.get.result == ComposeResult.TimingFailure) {
      val wns = run.result flatMap (_.timing) map (_.worstNegativeSlack) getOrElse -2.0
      val newFrequency = 1000.0 / ((1000.0 / run.element.frequency) - wns)
      val newH = ds.heuristic(run.element.composition, newFrequency, run.target)(cfg)
      val feasibleElem = DesignSpace.Element(run.element.composition, newFrequency, newH)
      // skip feedback elements with frequency of less than 50 MHz
      if (newFrequency >= 50.0) {
        Seq(new ConcreteRun(nextRunId, feasibleElem, run.target, debugMode))
      } else {
        Seq()
      }
    } else { Seq() }
  }

  private def generate(q: PriorityQueue[Run], batch: Batch): Unit = {
    import scala.collection.immutable.Map
    // compute generate set
    val generatees: Map[Run, Run] = (for {
      run <- batch.runs
      gen <- generate(space, run)
    } yield (run -> gen)).toMap
    _logger.debug("number of generatees: {}", generatees.size)
    // add to queue
    q ++= generatees.values
    // generate graph updates
    for ((run, gen) <- generatees) {
      val util = AreaUtilization(target, gen.element.composition)
      require (util.nonEmpty, "area must be known for generated elements")
      publish(Exploration.Events.RunGenerated(run.element, gen.element, util.get))
    }
    _logger.info("{} new elements generated after batch {}", generatees.size, batch.id)
  }

  def configuration: Configuration = cfg

  private def prune(q: PriorityQueue[Run], batch: Batch): Unit = {
    import scala.collection.immutable.Map
    // compute prune set
    val p: Map[Run, Seq[(Run, PruningReason)]] = (for {
      run <- batch.runs
    } yield run -> prune(q, run)).toMap
    // filter unique pruned elements
    val prunees: Set[Run] = (for { r <- p.values; pr <- r } yield pr._1).toSet
    _logger.info("{} elements pruned after batch {}", prunees.size, batch.id)
    // remove from queue
    val tmp = q filterNot (prunees contains _)
    q.clear()
    q ++= tmp
    // generate up to one event per batch run and reason
    for (run <- p.keySet; rmap = p(run) groupBy (_._2); r <- rmap) {
      publish(Exploration.Events.RunPruned(r._2 map (_._1.element), run.element, r._1))
    }
    _logger.debug("batch {}: {} elements left after prune", batch.id, q.length)
  }

  private def apply(q: PriorityQueue[Run], batchNumber: Int = 0): Option[Run] = if (q.isEmpty) {
    _logger.info("design space exhausted, no solution found :-(")
    None
  } else {
    val batch = createBatch(q, batchNumber)
    batch.start()
    _logger.info("batch {} finished, results: {}", batch.id,
      batch.runs flatMap (_.result) map (_.result) map (_.toString) mkString ", ")
    // check first if best in batch was a success and quit if that's the case
    if (! batch.isFirstSuccess) {//(batch.result.isEmpty) {
      _logger.debug("batch {}: {} elements left after finish", batch.id, q.length)
      generate(q, batch)
      prune(q, batch)
      _logger.info("batch {} finished without final result, {} elements left in design space", batch.id, q.length)
      // if all other elements were pruned and there is a result, take that instead
      if (q.length == 0 && ! batch.result.isEmpty) {
        _logger.info("design space exploration finished successfully: {}", batch.result.toString)
        batch.result
      } else {
        // return best result between this and next batch
        apply(q, batchNumber + 1) map { run => if (batch.result.isEmpty) {
            Some(run)
          } else if (run.element.h > batch.result.get.element.h) {
            Some(run)
          } else {
            batch.result
          }
        } getOrElse batch.result
      }
    } else {
      // best in batch is best overall, we can stop
      _logger.info("design space exploration finished successfully: {}", batch.result.toString)
      batch.result
    }
  }

  def start(): Option[(DesignSpace.Element, Composer.Result, Task)] = {
    _logger.debug("initial composition = {}", initialComposition.toString)
    _logger.debug("dimensions = {}", dimensions.toString)
    _logger.debug("target = {}", target.toString)
    _logger.trace("computing design space ...")
    val q = PriorityQueue[Run]()
    space.enumerate foreach { e =>
      val util = AreaUtilization(target, e.composition)
      require (util.nonEmpty, "area estimate must be known for all elements")
      val run = new ConcreteRun(nextRunId, e, target, debugMode)
      if (q.find(r =>(r compare run) == 0).isEmpty) {
        publish(Exploration.Events.RunDefined(e, util.get))
        q.enqueue(run)
      } else {
        val same = q.find(r =>(r compare run) == 0)
        same foreach { s =>
          _logger.error("element = %s, same as element = %s, run equals: %s, element.equals: %s"
            .format(s.element, run.element, run.equals(s), run.element.equals(s.element)))
        }
        _logger.error("tried to enqueue element twice: {}", run.toString)
      }
    }
    _logger.trace("design space computed, {} elements", q.length)
    _logger.debug("starting exploration")
    publish(Exploration.Events.ExplorationStarted(this))
    val result = apply(q)
    _logger.debug("exploration finished")
    result foreach { run => _result = Some((run.element, run.result.get)) }
    publish(Exploration.Events.ExplorationFinished(this))
    result map { run => (run.element, run.result.get , run.task.get) }
  }
}

object Exploration {
  // TODO better way to propagate DSE parameters?
  // scalastyle:off parameter.number
  def apply(initialComposition: Composition,
            dimensions: DesignSpace.Dimensions,
            target: Target,
            designFrequency: Heuristics.Frequency,
            batchSize: Int = MAX_BATCH_SZ,
            basePath: Path,
            debugMode: Option[String] = None) (implicit cfg: Configuration, tsk: Tasks): Exploration =
    new ConcreteExploration(initialComposition, target, dimensions, designFrequency, batchSize, basePath, debugMode)
  // scalastyle:on parameter.number

  final val MAX_BATCH_SZ: Int = 10 // FIXME use Compose.maxNumberOfThreads

  sealed trait PruningReason
  final object PruningReason {
    import PruningReasons._
    def apply(s: String): Option[PruningReason] = s.toLowerCase match {
      case "areaprune"      => Some(AreaPrune)
      case "frequencyprune" => Some(FrequencyPrune)
      case "worsethanprune" => Some(WorseThanPrune)
      case _                => None
    }
  }
  final object PruningReasons {
    final case object AreaPrune extends PruningReason
    final case object FrequencyPrune extends PruningReason
    final case object WorseThanPrune extends PruningReason
  }

  sealed trait Event
  object Events {
    final case class RunDefined(element: DesignSpace.Element, utilization: AreaEstimate) extends Event
    final case class RunStarted(element: DesignSpace.Element, task: ComposeTask) extends Event
    final case class RunFinished(element: DesignSpace.Element, task: ComposeTask) extends Event
    final case class RunGenerated(from: DesignSpace.Element, element: DesignSpace.Element, utilization: AreaEstimate) extends Event
    final case class RunPruned(elements: Seq[DesignSpace.Element], cause: DesignSpace.Element, reason: PruningReason) extends Event
    final case class BatchStarted(batchNumber: Int, elements: Seq[DesignSpace.Element]) extends Event
    final case class BatchFinished(batchNumber: Int, elements: Seq[DesignSpace.Element], results: Seq[Composer.Result]) extends Event {
      assert (elements.length == results.length,
        "elements length (%d) does not match results length (%d)".format(elements.length, results.length))
    }
    final case class ExplorationStarted(ex: Exploration) extends Event
    final case class ExplorationFinished(ex: Exploration) extends Event
  }
}
