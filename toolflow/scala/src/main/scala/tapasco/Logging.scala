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
package tapasco

import org.slf4j.LoggerFactory

import scala.util.control.Exception._

object Logging {
  type Logger = org.slf4j.Logger
  def logger(c: Class[_]): Logger = LoggerFactory.getLogger(c)
  def logger(n: String): Logger = LoggerFactory.getLogger(n)
  def rootLogger: ch.qos.logback.classic.Logger =
    LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME).asInstanceOf[ch.qos.logback.classic.Logger]

  def catchAllDefault[T](default: T, prefix: String = "")(body: => T)(implicit logger: Logger): T =
    (handling (classOf[Exception]) by (logDefault[T](default, prefix)(logger)(_))).apply(body)

  def catchDefault[T](default: T, es: Seq[Class[_]], prefix: String = "")
                     (body: => T)
                     (implicit logger: Logger): T =
    (handling (es: _*) by (logDefault[T](default, prefix)(logger)(_))).apply(body)

  private def logDefault[T](default: T, prefix: String)(logger: Logger)(t: Throwable) = {
    logger.warn("%s%s".format(prefix, t))
    logger.debug("%sstacktrace:\n%s".format(prefix, t.getStackTrace() mkString "\n"))
    default
  }
}
