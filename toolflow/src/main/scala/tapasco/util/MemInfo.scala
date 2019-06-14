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
 * @file     MemInfo.scala
 * @brief    Wrapper for /proc/meminfo; retrieve info about memory configuration.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.io.Source

/** Memory information entry. **/
sealed case class MemEntry(name: String, amount: Int, unit: String)

/** MemInfo class: Reads /proc/meminfo, provides dictionary access. **/
object MemInfo {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private lazy val warnOnceMaxValue = {
    logger.warn("could not read /proc/meminfo, assuming infinite memory")
    Int.MaxValue
  }
  val meminfo = try {
    for (l <- Source.fromFile("/proc/meminfo").getLines.toSeq;
         m <- """^(\S*)\s*:\s+(\d+)\s*(\S+)*""".r.findFirstMatchIn(l);
         e <- try { Some(MemEntry(m.group(1), m.group(2).toInt, if (Option(m.group(3)).nonEmpty) m.group(3) else "")) }
              catch { case e: Exception => None }) yield e
  } catch { case _: Exception => Seq() }

  def apply(regex: String): Seq[MemEntry] = meminfo filter (me => ! regex.r.findFirstIn(me.name).isEmpty)
  def totalMemory: Int = apply("MemTotal").headOption map (_.amount) getOrElse warnOnceMaxValue
  def freeMemory: Int = apply("MemFree").headOption map (_.amount) getOrElse warnOnceMaxValue
}
