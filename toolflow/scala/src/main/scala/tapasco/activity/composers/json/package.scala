/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco.activity.composers

import java.nio.file._

import play.api.libs.functional.syntax._
import play.api.libs.json._
import tapasco.reports._

/** Json serializers and deserializers. */
package object json {

  implicit object ComposerImplementationFormat extends Format[Composer.Implementation] {
    def reads(json: JsValue): JsResult[Composer.Implementation] = json match {
      case JsString(str) => JsSuccess(Composer.Implementation(str))
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.string"))))
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
                               timing: Option[String]) = Composer.Result(
    r,
    bit,
    log flatMap (f => ComposerLog(Paths.get(f))),
    util flatMap (f => UtilizationReport(Paths.get(f))),
    timing flatMap (f => TimingReport(Paths.get(f)))
  )

  private def wrComposerResult(r: Composer.Result) = (
    r.result,
    r.bit,
    r.log map (_.file.toString),
    r.util map (_.file.toString),
    r.timing map (_.file.toString)
  )

  implicit val composerResultFormat: Format[Composer.Result] = (
    (JsPath \ "Result").format[ComposeResult] ~
      (JsPath \ "Bitstream").formatNullable[String] ~
      (JsPath \ "Log").formatNullable[String] ~
      (JsPath \ "UtilizationReport").formatNullable[String] ~
      (JsPath \ "TimingReport").formatNullable[String]
    ) (mkComposerResult _, wrComposerResult _)
}
