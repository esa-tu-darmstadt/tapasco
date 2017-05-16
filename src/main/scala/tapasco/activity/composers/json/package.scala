package de.tu_darmstadt.cs.esa.tapasco.activity.composers
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  play.api.libs.json._
import  play.api.libs.functional.syntax._
import  java.nio.file._

/** Json serializers and deserializers. */
package object json {
  implicit object ComposerImplementationFormat extends Format[Composer.Implementation] {
    def reads(json: JsValue): JsResult[Composer.Implementation] = json match {
      case JsString(str) => JsSuccess(Composer.Implementation(str))
      case _             => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.string"))))
    }
    def writes(i: Composer.Implementation): JsValue = JsString(i.toString)
  }

  implicit val composeResultFormat = new Format[ComposeResult] {
    def reads(json: JsValue): JsResult[ComposeResult] = json match {
      case JsString(s) => ComposeResult(s) match {
        case Some(r) => JsSuccess(r)
        case None => JsError(Seq(JsPath() -> Seq(JsonValidationError("invalid.compose.result.value"))))
      }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.compose.result.string.value"))))
    }
    def writes(r: ComposeResult): JsValue = JsString(r.toString)
  }

  private def mkComposerResult(r: ComposeResult, bit: Option[String], log: Option[String], util: Option[String],
      timing: Option[String], power: Option[String]) = Composer.Result(
    r,
    bit,
    log flatMap    (f => ComposerLog(Paths.get(f))),
    util flatMap   (f => UtilizationReport(Paths.get(f))),
    timing flatMap (f => TimingReport(Paths.get(f))),
    power flatMap  (f => PowerReport(Paths.get(f)))
  )

  private def wrComposerResult(r: Composer.Result) = (
    r.result,
    r.bit,
    r.log map (_.file.toString),
    r.util map (_.file.toString),
    r.timing map (_.file.toString),
    r.power map (_.file.toString)
  )

  implicit val composerResultFormat: Format[Composer.Result] = (
    (JsPath \ "Result").format[ComposeResult] ~
    (JsPath \ "Bitstream").formatNullable[String] ~
    (JsPath \ "Log").formatNullable[String] ~
    (JsPath \ "UtilizationReport").formatNullable[String] ~
    (JsPath \ "TimingReport").formatNullable[String] ~
    (JsPath \ "PowerReport").formatNullable[String]
  ) (mkComposerResult _, wrComposerResult _)
}
