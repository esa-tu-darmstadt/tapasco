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
package de.tu_darmstadt.cs.esa.tapasco.util
import  java.util.WeakHashMap
import  scala.collection.JavaConverters._

class Memoization[A, B](f: A => B) extends Function[A, B] {
  private val _memo = new WeakHashMap[A, B]().asScala
  def apply(a: A): B = _memo.synchronized {
    _memo.getOrElse(a, {
      val r = f(a)
      _memo += a -> r
      r
    })
  }

  def remove(a: A): this.type = _memo.synchronized { _memo.remove(a); this }
  def clear(): this.type      = _memo.synchronized { _memo.clear(); this }
}

object Memoization {
  def dump[A, B](m: Memoization[A, B], osw: java.io.OutputStreamWriter): Unit = {
    val NL = scala.util.Properties.lineSeparator
    osw
      .append("<Memoization>").append(NL)
      .append("<<_memo>>").append(m._memo map (_.toString) mkString (NL)).append(NL)
      .append(NL)
  }
}
