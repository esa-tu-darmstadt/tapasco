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
package tapasco.parser

import fastparse.all._
import tapasco.base._

import scala.util.Properties.{lineSeparator => NL}

object CommandLineParser {
  import BasicParsers._
  import GlobalOptions._
  import JobParsers._

  private final val logger = tapasco.Logging.logger(getClass)

  private[parser] def args: Parser[Configuration] =
    globalOptions ~ ws ~/ jobs ~ ws ~ End map { case (c, js) => c.jobs(c.jobs ++ js) }

  def apply(arguments: String): Either[ParserException, Configuration] =
    check(args.parse(arguments))

  case class ParserException(expected: String, index: Int, input: String, marker: String) extends Throwable {
    override def toString(): String = Seq(
      "expected %s at %d".format(expected, index),
      "",
      "\t" + input,
      "\t" + marker
    ) mkString NL
  }

  object ParserException {
    private final val SLICE_LEFT   = -100
    private final val SLICE_RIGHT  = 40

    def apply(f: Parsed.Failure): ParserException =
      ParserException(f.lastParser.toString,
                      f.index,
                      f.extra.input.slice(f.index + SLICE_LEFT, f.index + SLICE_RIGHT)
                                   .replace ("\t", " ")
                                   .replace ("\n", " "),
                      ("~" * f.index + "^").slice(f.index + SLICE_LEFT,
                                                  f.index + SLICE_RIGHT))
  }

  def check[A](x: Parsed[A]): Either[ParserException, A] = x match {
    case f: Parsed.Failure      => Left(ParserException(f))
    case Parsed.Success(cfg, _) => Right(cfg)
  }
}
