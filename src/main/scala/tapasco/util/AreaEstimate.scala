//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
 * @file     AreaEstimate.scala
 * @brief    Model of FPGA area estimate.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.e)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.util.Properties.{lineSeparator => NL}

/** Estimate of resource usage of a hardware design. */
final case class ResourcesEstimate(
    SLICE: Int,
    LUT: Int,
    FF: Int,
    DSP: Int,
    BRAM: Int) extends Ordered[ResourcesEstimate] {
  import scala.math.Ordered.orderingToOrdered
  override def toString: String = List(
    "ResourcesEstimate: ",
    "  SLICE: " + BRAM,
    "  LUT  : " + LUT,
    "  FF   : " + FF,
    "  DSP  : " + DSP,
    "  BRAM : " + BRAM
  ).mkString(NL)

  def *(n: Int): ResourcesEstimate = ResourcesEstimate(
      SLICE * n,
      LUT * n,
      FF * n,
      DSP * n,
      BRAM * n
    )

  def +(r: ResourcesEstimate): ResourcesEstimate = ResourcesEstimate(
      SLICE + r.SLICE,
      LUT + r.LUT,
      FF + r.FF,
      DSP + r.DSP,
      BRAM + r.BRAM
    )
  def compare(that: ResourcesEstimate): Int =
    (this.LUT, this.FF, this.DSP, this.BRAM) compare (that.LUT, that.FF, that.DSP, that.BRAM)
}

/**
 * Estimate of the area usage of a hardware design relative to the available resources.
 **/
final case class AreaEstimate(
    resources: ResourcesEstimate,
    available: ResourcesEstimate) extends Ordered[AreaEstimate] {
  private val formatter = new java.text.DecimalFormat("#.#")

  val slice = resources.SLICE * 100.0 / available.SLICE
  val lut = resources.LUT * 100.0 / available.LUT
  val ff = resources.FF * 100.0 / available.FF
  val dsp = resources.DSP * 100.0 / available.DSP
  val bram = resources.BRAM  * 100.0 / available.BRAM
  val utilization = lut

  override lazy val toString: String = List(
    "AreaEstimate: ",
    "  SLICE: " + resources.SLICE + " / " + available.SLICE + " (" + formatter.format(slice) + "%)",
    "  LUT: " + resources.LUT + " / " + available.LUT + " (" + formatter.format(lut) + "%)",
    "  FF: " + resources.FF + " / " + available.FF + " (" + formatter.format(ff) + "%)",
    "  DSP: " + resources.DSP + " / " + available.DSP + " (" + formatter.format(dsp) + "%)",
    "  BRAM: " + resources.BRAM + " / " + available.BRAM + " (" + formatter.format(bram) + "%)",
    "  Utilization: " + formatter.format(utilization) + "%"
  ).mkString(NL)

  def *(n: Int): AreaEstimate = AreaEstimate(resources * n, available)
  def +(a: AreaEstimate): AreaEstimate = AreaEstimate(resources + a.resources, available)
  def isFeasible: Boolean = List(slice, lut, ff, dsp, bram).map(x => x <= 100.0).reduce(_&&_)
  def compare(that: AreaEstimate): Int = this.resources compare that.resources
}
