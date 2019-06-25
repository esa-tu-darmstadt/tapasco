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
package tapasco.dse.log

import java.time.LocalDateTime

import play.api.libs.functional.syntax._
import play.api.libs.json._
import tapasco.dse._
import tapasco.dse.json._
import tapasco.dse.log.ExplorationLog.Entry

package object json {
  implicit val entryFormats: Format[Entry] = (
    (JsPath \ "Timestamp").format[LocalDateTime] ~
    (JsPath \ "Event").format[Exploration.Event]
  ) (Tuple2.apply _, unlift(Tuple2.unapply _))

  implicit val logReads: Reads[ExplorationLog] =
    JsPath.read[Seq[Entry]] map { ExplorationLog.apply _ }
  implicit val logWrites = new Writes[ExplorationLog] {
    def writes(e: ExplorationLog) = Json.toJson(e.events)
  }
}
