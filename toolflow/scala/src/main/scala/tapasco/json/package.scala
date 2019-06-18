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
package de.tu_darmstadt.cs.esa.tapasco
import  java.nio.file._
import  play.api.libs.json._

/** Global helpers for JSON Serialization/Deserialization. */
package object json {
  private implicit val logger = Logging.logger(getClass)
  import Logging._

  /** Implicit Format for java.nio.file.Path. */
  implicit val pathFormat: Format[Path] = new Format[Path] {
    private[this] def mkError(p: String): JsResult[Path] =
      JsError(Seq(JsPath() -> Seq(JsonValidationError("invalid.path(%s)".format(p)))))
    def reads(json: JsValue): JsResult[Path] = json match {
      case JsString(p) => catchAllDefault(mkError(p), "invalid path (%s): ".format(p)) { JsSuccess(Paths.get(p)) }
      case _           => JsError(Seq(JsPath() -> Seq(JsonValidationError("validation.error.expected.jsstring"))))
    }
    def writes(p: Path): JsValue = JsString(p.toString)
  }

  /** Simple predicate: Path must exist in filesystem. */
  def mustExist(p: Path): Boolean = p.toFile.exists
}
