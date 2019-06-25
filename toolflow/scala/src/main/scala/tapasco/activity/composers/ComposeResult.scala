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
package tapasco.activity.composers

/** Possible result kinds of composition runs. */
sealed trait ComposeResult

object ComposeResult {
  final case object Success extends ComposeResult
  final case object TimingFailure extends ComposeResult
  final case object Timeout extends ComposeResult
  final case object PlacerError extends ComposeResult
  final case object OtherError extends ComposeResult

  def apply(s: String): Option[ComposeResult] = s.toLowerCase match {
    case "success" => Some(Success)
    case "timingfailure" => Some(TimingFailure)
    case "timeout" => Some(Timeout)
    case "placererror" => Some(PlacerError)
    case "othererror" => Some(OtherError)
    case _ => None
  }
}
