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
 * @file    Template.scala
 * @brief   Class for needle templating.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  java.io._
import  scala.collection.mutable.Map
import  scala.io.Source
import  scala.util.Properties
import  scala.util.matching.Regex

object Template {
  /** Default regex for needles. */
  val DEFAULT_NEEDLE = """@@([^@]+)@@""".r

  def findNeedles(nr: Regex = DEFAULT_NEEDLE, s: String): Set[String] =
    (for (m <- nr findAllMatchIn s) yield m group 1).toSet

  def findNeedlesInFile(nr: Regex = DEFAULT_NEEDLE, fn: String): Set[String] =
    Source.fromFile(fn).getLines map (findNeedles(nr, _)) reduce (_++_)

  def interpolate(nr: Regex, s: String, ms: Map[String, String]*): String =
    nr.replaceAllIn(s, m => (ms reduce (_++_)).getOrElse(m group 1, ""))

  def interpolateFile(nr: Regex, fn: String, ms: Map[String, String]*): String =
    interpolate(nr, Source.fromFile(fn).getLines.mkString(Properties.lineSeparator), ms:_*)

  def interpolateFile(nr: Regex, fn: String, outfn: String, ms: Map[String, String]*): Unit =
    new FileWriter(outfn).append(interpolateFile(nr, fn, ms:_*)).close()
}

/**
 * Simple class to perform string-string-replacements in needle template files.
 **/
class Template(nr: Regex = Template.DEFAULT_NEEDLE) extends Map[String, String]{
  /** Internal map of needles to replacements. */
  private val needles: Map[String, String] = Map()

  /**
   * Interpolates the contents of the given file with the current needles.
   * @param fn filename
   * @return file contents with substituted needles
   **/
  def interpolateFile(fn: String): String = Template.interpolateFile(nr, fn, needles)

  /**
   * Interpolates the contents of the given file with the current needles and
   * writes the modified content to the other file (truncated).
   * @param fn filename
   * @param outfn filename of output file
   **/
  def interpolateFile(fn: String, outfn: String): Unit =
    new FileWriter(outfn).append(interpolateFile(fn)).close()

  /**
   * Interpolates a string with the current needles.
   * @param s String to interpolate
   * @return modified string
   **/
  def interpolate(s: String): String = Template.interpolate(nr, s, needles)

  /* trait Map[String, String] */
  def get(key: String): Option[String] = needles.get(key)
  def iterator: Iterator[(String, String)] = needles.iterator
  override def -=(key: String): Template.this.type = { needles -= key; this }
  override def +=(kv: (String, String)): Template.this.type = { needles += kv; this }
}
