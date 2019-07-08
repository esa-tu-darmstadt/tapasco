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

import java.nio.file._

import play.api.libs.json.Reads.{filter, seq}
import play.api.libs.json._

/** Global helpers for JSON Serialization/Deserialization. */
package object json {
  private implicit val logger = Logging.logger(getClass)

  import Logging._

  /** Implicit Format for java.nio.file.Path. */
  implicit val pathFormat: Format[Path] = new Format[Path] {
    private[this] def mkError(p: String): JsResult[Path] =
      JsError(Seq(JsPath() -> Seq(JsonValidationError("invalid.path(%s)".format(p)))))

    def reads(json: JsValue): JsResult[Path] = json match {
      case JsString(p) => catchAllDefault(mkError(p), "invalid path (%s): ".format(p)) {
        JsSuccess(Paths.get(p))
      }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("validation.error.expected.jsstring"))))
    }

    def writes(p: Path): JsValue = JsString(p.toString)
  }

  /** Simple predicate: Path must exist in filesystem. */
  def mustExist(p: Path): Boolean = p.toFile.exists

  /**
    * Verification Functions to enable error messages for json Parsing.
    */

  /**
    * Log Error if x <= 0.
    */
  val greaterZeroIntValidation = filter[Int](JsonValidationError("Value musst be greater than zero."))(x => x > 0)

  /**
    * Log Error if x.length < 1
    */
  val nonEmptyStringValidation = filter[String](JsonValidationError("String must be non-empty."))(x => x.length > 0)

  def pathExistsValidation(basePath: Path):Reads[Path] =
    filter[Path](JsonValidationError("File or Dir does not exist."))(x => {
      val filePath = basePath.resolve(x).toAbsolutePath
      val r = mustExist(filePath)
      r
    })
  def pathsExistValidation(basePath: Path):Reads[Seq[Path]] = seq[Path](pathExistsValidation(basePath))

  val nonEmptyStringsValidation = seq[String](nonEmptyStringValidation)



}
