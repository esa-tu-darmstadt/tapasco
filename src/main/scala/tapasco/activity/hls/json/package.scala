package de.tu_darmstadt.cs.esa.tapasco.activity.hls
import  play.api.libs.json._
import  HighLevelSynthesizer._

package object json {
  implicit object HLSImplementationFormat extends Format[HighLevelSynthesizer.Implementation] {
    def reads(json: JsValue): JsResult[Implementation] = json match {
      case JsString(str) => JsSuccess(HighLevelSynthesizer.Implementation(str))
      case _             => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.string"))))
    }
    def writes(i: Implementation): JsValue = JsString(i.toString)
  }
}
