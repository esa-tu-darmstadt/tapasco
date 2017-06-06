//
// Copyright (C) 2016 Jens Korinth, TU Darmstadt
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
/**
 * @file     Composer.scala
 * @brief    Abstract trait for synthesis tool wrappers that perform the actual
 *           synthesis, place and route steps for the Composition.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.activity.composers
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.reports._

/** Wrapper trait for synthesis tools: basic interface to synthesise compositions
    using an external tool (e.g., Vivado). **/
trait Composer {
  import Composer._

  /** Returns the approximate peak memory usage per process in GiB. **/
  def maxMemoryUsagePerProcess: Int

  /** Start run of external tool.
   *  @param bd Composition to synthesize
   *  @param target Platform and Architecture combination to synthesize for
   *  @param f target design frequency (PE speed)
   *  @param archFeatures ArchitectureFeatures (optional).
   *  @param platformFeatures Platform features (optional).
   *  @param cfg implicit Configuration instance
   *  @return Composer.Result with error code / additional data
   **/
  def compose(bd: Composition, target: Target, f: Double = 0, archFeatures: Seq[Feature] = Seq(),
      platformFeatures: Seq[Feature] = Seq())(implicit cfg: Configuration): Result

  /** Removes all intermediate files for the run, leaving results.
   *  @param bd Composition to synthesize
   *  @param target Platform and Architecture combination to synthesize for
   *  @param f target design frequency (PE speed)
   *  @param cfg implicit Configuration instance
   **/
  def clean(bd: Composition, target: Target, f: Double = 0)(implicit cfg: Configuration): Unit

  /** Removes all files for the run, including results.
   *  @param bd Composition to synthesize
   *  @param target Platform and Architecture combination to synthesize for
   *  @param f target design frequency (PE speed)
   *  @param cfg implicit Configuration instance
   **/
  def cleanAll(bd: Composition, target: Target, f: Double = 0)(implicit cfg: Configuration): Unit
}

object Composer {
  sealed trait Implementation
  object Implementation {
    final case object Vivado extends Implementation
    def apply(str: String): Implementation = str.toLowerCase match {
      case "vivado" => Vivado
      case _        => throw new Exception("unknown composer implementation: '%s'".format(str))
    }
  }

  def apply(i: Implementation)(implicit cfg: Configuration): Composer = i match {
    case Implementation.Vivado => new VivadoComposer()(cfg)
  }

  /** Make a name for the Composer project. */
  def mkProjectName(c: Composition, t: Target, f: Heuristics.Frequency): String = "%s--%s--%s".format(
    "%s-%s".format(t.ad.name, t.pd.name),
    c.composition map (ce => "%s_%d".format(ce.kernel.replaceAll(" ", "-"), ce.count)) mkString ("_"),
    "%05.1f".format(f))

  /** Extended result with additional information as provided by the tool. **/
  final case class Result(
    result: ComposeResult,
    bit:    Option[String]            = None,
    log:    Option[ComposerLog]       = None,
    util:   Option[UtilizationReport] = None,
    timing: Option[TimingReport]      = None,
    power:  Option[PowerReport]       = None
  )

  /** Result of the external process execution. **/
  object Result { def apply(e: Throwable): Result = Result(ComposeResult.OtherError) }
}
