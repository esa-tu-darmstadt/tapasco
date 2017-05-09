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
 * @file    Feature.scala
 * @brief   TPC Architecture / Platform features.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base

sealed abstract class Feature(val enabled: Boolean)

// scalastyle:off magic.number
object Feature {
  final case class LED(override val enabled: Boolean) extends Feature(enabled)
  final case class OLED(override val enabled: Boolean) extends Feature(enabled)
  final case class Cache(override val enabled: Boolean, size: Int, associativity: Int) extends Feature(enabled) {
    private val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
    private def cacheSizeSupported(n: Int): Boolean = {
      val supportedSizes = List(32768, 65536, 131072, 262144, 524288)
      val ok = supportedSizes.contains(n)
      if (! ok) {
        logger.warn("Cache size " + n + " is not supported, " +
          "ignoring cache configuration. Supported sizes: " + supportedSizes)
      }
      ok
    }

    require (cacheSizeSupported(size), "cache size %d is not supported".format(size))
  }
  final case class Debug(override val enabled: Boolean, depth: Option[Int], stages: Option[Int],
      useDefaults: Option[Boolean], nets: Option[Seq[String]]) extends Feature(enabled) {
    private val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
    private def dataDepthSupported(n: Int): Boolean = {
      val supportedDepths = List(1024, 2048, 4096, 8192, 16384)
      val ok = supportedDepths.contains(n)
      if (! ok) {
        logger.warn("Debug core data depth " + n + " is not supported, " +
          "ignoring debug configuration. Supported sizes: " + supportedDepths)
      }
      ok
    }

    private def stagesSupported(n: Int): Boolean = n >= 0 && n <= 6

    depth foreach { d => require(dataDepthSupported(d), "data depth %d not supported".format(d)) }
    stages foreach { s => require(stagesSupported(s), "%d stages not supported".format(s)) }
  }
}
// scalastyle:on magic.number
