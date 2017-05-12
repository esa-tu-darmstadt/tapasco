//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// // Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file     SequenceMatcher.scala
 * @brief    Multi-line stateful regex matcher for text file parsing.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.util.matching._
import  scala.util.matching.Regex.Match

/** Text matching class that matches incoming line-wise text to a sequence of regular
    expressions. Helper to match multi-line stuff in text files. **/
private[tapasco] class SequenceMatcher[T](ors : Regex*)(implicit mustMatchEveryLine: Boolean = false,
    cons: Seq[Match] => T = identity[Seq[Match]] _) {
  private val or: Seq[Regex] = ors.toSeq
  private var rs: Seq[Regex] = ors.toSeq
  private var ms: Seq[Match] = Seq()
  def matched: Boolean = rs.isEmpty
  def matches: Seq[Match] = ms
  def result: Option[T] = if (matched) Some(cons(matches)) else None
  def update(line: String): Boolean = {
    if (rs.isEmpty) { true }
    else {
      val m = rs.head.findFirstMatchIn(line)
      if (m.isEmpty) {
        if (mustMatchEveryLine) rs = or
        false
      } else {
        ms = ms :+ m.get
        rs = rs.tail
        rs.isEmpty
      }
    }
  }
}

/** Repeats a [[SequenceMatcher]] to generate a Seq[T]. */
private[tapasco] class RepSeqMatcher[T](ors: Regex*)(implicit mustMatchEveryLine: Boolean = false,
    cons: Seq[Match] => T = identity[Seq[Match]] _) {
  private var matcher = new SequenceMatcher(ors:_*)(mustMatchEveryLine, cons)
  private val _result = new scala.collection.mutable.ArrayBuffer[T]()
  def update(line: String): Boolean = {
    matcher.update(line)
    if (matcher.matched) {
      _result += matcher.result.get
      matcher = new SequenceMatcher(ors:_*)(mustMatchEveryLine, cons)
    }
    matcher.matched
  }
  def result: Option[Seq[T]] = if (_result.isEmpty) None else Some(_result.toSeq)
  def matched: Boolean = _result.nonEmpty
}
