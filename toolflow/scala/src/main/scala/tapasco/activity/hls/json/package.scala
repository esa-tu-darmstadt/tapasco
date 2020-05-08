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
package tapasco.activity.hls

import play.api.libs.json._
import tapasco.activity.hls.HighLevelSynthesizer._

package object json {

  implicit object HLSImplementationFormat extends Format[HighLevelSynthesizer.Implementation] {
    def reads(json: JsValue): JsResult[Implementation] = json match {
      case JsString(str) => JsSuccess(HighLevelSynthesizer.Implementation(str))
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.string"))))
    }

    def writes(i: Implementation): JsValue = JsString(i.toString)
  }

}
