package de.tu_darmstadt.cs.esa.tapasco.dse.log
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.json._
import  play.api.libs.json._
import  play.api.libs.functional.syntax._
import  java.time.LocalDateTime
import  ExplorationLog.Entry

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
