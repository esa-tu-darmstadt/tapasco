package de.tu_darmstadt.cs.esa.tapasco.itapasco.globals
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.util._

/** Controller for application-wide [[base.Configuration]] instance.
  * Makes current global configuration accessible and publishes
  * change events on modification.
  **/
protected[itapasco] object Config extends Publisher {
  sealed trait Event
  final object Events {
    /** Raised when internal configuration changes. */
    final case class ConfigurationChanged(c: Configuration) extends Event
  }

  private var _cfg: Configuration = Configuration()

  /** Returns the current [[base.Configuration]]. */
  def configuration: Configuration = _cfg.jobs(Seq(Job.job))
  /** Sets the currenct [[base.Configuration]] (use .copy to modify). */
  def configuration_=(cfg: Configuration): Unit = if (! _cfg.equals(cfg)) {
    _cfg = cfg
    publish(Events.ConfigurationChanged(_cfg))
  }
}
