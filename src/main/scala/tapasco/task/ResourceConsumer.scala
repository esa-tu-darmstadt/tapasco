package de.tu_darmstadt.cs.esa.tapasco.task
import  de.tu_darmstadt.cs.esa.tapasco.slurm._

/**
 * ResourceConsumers advertise their usage of CPUs, Memory and licences.
 **/
trait ResourceConsumer {
  /** Number of CPUs this consumer will use during run (max.). */
  val cpus: Int
  /** Number of bytes of RAM this consumer will use during run (max.). */
  val memory: Int
  /** Number of licences per feature this consumer will use during run (max.). */
  val licences: Map[String, Int]

  /** Returns true, if the consumer can be started immediately. */
  def canStart: Boolean = true

  /** Create merged consumer by summing the resource requirements. */
  def +(other: ResourceConsumer): ResourceConsumer = ResourceConsumer.merge(this, other)

  /** Returns true, if this consumer uses more resources than other. */
  def usesMoreThan(other: ResourceConsumer): Boolean = if (! Slurm.enabled) {
    cpus > other.cpus ||
    (licences.keys map { k => licences(k) > other.licences.getOrElse(k, Integer.MAX_VALUE) } fold false) (_ || _)
  } else {
    (licences.keys map { k => licences(k) > other.licences.getOrElse(k, Integer.MAX_VALUE) } fold false) (_ || _)
  }

  override lazy val toString: String = "(cpus: %d, mem: %d, licences: %s)".format(cpus, memory, licences)
}

/** ResourceConsumer companion object. **/
object ResourceConsumer {
  /**
   * Create a new ResourceConsumer.
   * @param ccpus Number of CPUs this consumer will use during run (max.).
   * @param cmemory Number of bytes of RAM this consumer will use during run (max.).
   * @param licences Number of licences per feature this consumer will use during run (max.).
  **/
  def apply(ccpus: Int, cmemory: Int, clicences: Map[String, Int]): ResourceConsumer = new ResourceConsumer {
    val cpus = ccpus
    val memory = cmemory
    val licences = clicences
  }

  private[ResourceConsumer]
  def mergeLicences(a: ResourceConsumer, b: ResourceConsumer): Map[String, Int] =
    ((a.licences.keys ++ b.licences.keys) map { k =>
      k -> (a.licences.getOrElse(k, 0) + b.licences.getOrElse(k, 0))
    }).toMap

  private[ResourceConsumer]
  def merge(a: ResourceConsumer, b: ResourceConsumer) = new ResourceConsumer {
    val cpus = a.cpus + b.cpus
    val memory = a.memory + b.memory
    val licences = mergeLicences(a, b)
  }

  /** ResourceConsumer with no resource requirements. **/
  object NullConsumer extends ResourceConsumer {
    val cpus = 0
    val memory = 0
    val licences: Map[String, Int] = Map()
  }
}

