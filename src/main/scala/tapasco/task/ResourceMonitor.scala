package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.util.{MemInfo, FlexLicenceManagerStatus}

/**
 * ResourceMonitors manage a fixed pool of resources and consumers working with
 * these resources. A task scheduler can use the ResourceMonitor to provide a
 * safe scheduling of resource-sensitive tasks.
 **/
trait ResourceMonitor {
  def canStart(t: ResourceConsumer): Boolean
  def doStart(t: ResourceConsumer): Unit
  def didFinish(t: ResourceConsumer): Unit
  def status: String
}


/**
 * Default implementation of a ResourceMonitor:
 * Monitors CPUs, memory and licences.
 **/
private class DefaultResourceMonitor extends ResourceMonitor {
  import scala.collection.mutable.Set
  private[this] val _cpus = Runtime.getRuntime().availableProcessors()
  private[this] val _mem  = MemInfo.totalMemory
  private[this] val _cons = Set[ResourceConsumer]()
  private val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private[this] val _available = new ResourceConsumer {
    val cpus = _cpus
    val memory = _mem
    val licences = FlexLicenceManagerStatus.licences map (c => (c._1, c._2._1))
  }

  private def current = (_cons fold ResourceConsumer.NullConsumer) (_ + _)
  private def check(cons: Set[ResourceConsumer]) = {
    logger.trace("checking: {}, available: {}", (cons fold ResourceConsumer.NullConsumer) (_ + _): Any, _available)
    ! ((cons fold ResourceConsumer.NullConsumer) (_ + _) usesMoreThan _available)
  }

  def doStart(t: ResourceConsumer): Unit     = if (canStart(t)) _cons += t
  def didFinish(t: ResourceConsumer): Unit   = _cons -= t
  def canStart(t: ResourceConsumer): Boolean = Slurm.enabled || (t.canStart && check(_cons + t))
  def status: String = "%d active consumers, %d/%d CPUs, %1.1f/%1.1f GiB RAM, %d total licences in use".format(
    _cons.size, current.cpus, _cpus,
    current.memory / 1024.0 / 1024.0,
    _mem / 1024.0 / 1024.0,
    (current.licences.values fold 0) (_ + _)
  )
}

/** ResourceMonitor companion object. **/
object ResourceMonitor {
  /** Obtain a new ResourceMonitor. **/
  def apply(): ResourceMonitor = new DefaultResourceMonitor()
}

