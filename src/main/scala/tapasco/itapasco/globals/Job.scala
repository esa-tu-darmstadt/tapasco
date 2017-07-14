package de.tu_darmstadt.cs.esa.tapasco.itapasco.globals
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file._

protected[itapasco] object Job extends Publisher {
  private[this] final val INITIAL_FREQUENCY = 50
  sealed trait Event
  object Events {
    final case class JobChanged(job: DesignSpaceExplorationJob) extends Event
  }

  private var _job = DesignSpaceExplorationJob(
    initialComposition = Composition(Paths.get("N/A"), None, Seq()),
    initialFrequency = INITIAL_FREQUENCY,
    dimensions = DesignSpace.Dimensions(frequency = true),
    heuristic = Heuristics.ThroughputHeuristic,
    batchSize = Runtime.getRuntime().availableProcessors(),
    basePath = None,
    _architectures = None,
    _platforms = None,
    features = None,
    debugMode = None
  )

  def job: DesignSpaceExplorationJob = _job
  def job_=(j: DesignSpaceExplorationJob): Unit = if (! j.equals(_job)) {
    _job = j
    publish(Events.JobChanged(_job))
  }
}
