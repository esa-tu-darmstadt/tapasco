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
package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._

private object HighLevelSynthesisParser {
  import BasicParsers._
  import CommonArgParsers._

  def hls: Parser[HighLevelSynthesisJob] =
    IgnoreCase("hls") ~ ws ~/ kernels ~ ws ~/ options map { case (ks, optf) =>
      optf(HighLevelSynthesisJob(_implementation = "VivadoHLS",
                                 _kernels = ks))
    }

  private def kernels: Parser[Option[Seq[String]]] = (
    ((IgnoreCase("all").! ~/ ws) map (_ => None)) |
    ((seqOne(kernel) ~/ ws) map { Some(_) })
  ).opaque("either 'all', or a list of kernel names")

  private val jobid = identity[HighLevelSynthesisJob] _

  private def options: Parser[HighLevelSynthesisJob => HighLevelSynthesisJob] =
    (implementation | architectures | platforms).rep map (opt =>
      (opt map (applyOption _) fold jobid) (_ andThen _))

  private def applyOption(opt: (String, _)): HighLevelSynthesisJob => HighLevelSynthesisJob =
    opt match {
      case ("Implementation", i: String) => _.copy(_implementation = i)
      case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
      case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
      case o => throw new Exception(s"parsed illegal option: $o")
    }
}
