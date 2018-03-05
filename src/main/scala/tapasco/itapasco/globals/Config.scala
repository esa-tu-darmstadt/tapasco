//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
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
