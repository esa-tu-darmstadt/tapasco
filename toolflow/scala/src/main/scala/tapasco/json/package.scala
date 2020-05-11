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
package tapasco

import java.nio.file._

import play.api.libs.json.Reads.{filter, seq}
import play.api.libs.json._
import tapasco.base.Kernel

/** Global helpers and validators for JSON Serialization/Deserialization. */
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
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError(JsonErrors.ERROR_EXPECTED_JSSTRING))))
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
  def greaterZeroIntValidation: Reads[Int] = filter[Int](JsonValidationError("Value musst be greater than zero."))(x => x > 0)

  /**
    * Log Error if x.length < 1 for one or many strings.
    */
  def minimumLength(length: Int): Reads[String] = filter[String](JsonValidationError(s"String must have at least $length characters."))(x => x.length >= length)
  def allMinimumLength(length: Int): Reads[Seq[String]] = seq[String](minimumLength(length))

  /**
    * Ensure that one or many files exist as declared.
    * @param basePath Path of the kernel.json
    */
  def pathExistsValidation(basePath: Path):Reads[Path] =
    filter[Path](JsonValidationError(JsonErrors.ERROR_EXPECTED_FILEORDIREXISTS))(x => {
      val filePath = basePath.resolve(x).toAbsolutePath
      val r = mustExist(filePath)
      r
    })
  def pathsExistValidation(basePath: Path):Reads[Seq[Path]] = seq[Path](pathExistsValidation(basePath))

  /**
    * Ensure that one or many values are within bounds.
    */
  def withinBounds(lowerBound: Int, upperBound: Int): Reads[Int] =
    filter[Int](JsonValidationError(s"Value must be within the range of [$lowerBound, $upperBound]"))(x => x >= lowerBound && x <= upperBound)
  def allWithinBounds(lowerBound: Int, upperBound: Int): Reads[Seq[Int]] = seq[Int](withinBounds(upperBound, lowerBound))

  /**
    * Ensure that the String is a valid passing convention.
    */
  def isPassingConvention: Reads[String] = filter[String](JsonValidationError("Can only be valid passing convention (\"by value\" or \"by reference\")."))(
    x => List("by value", "by reference").contains(x)
  )

  /**
    * Ensure that the Kernel ID is valid, eg greater 0.
    *
    * @return
    */
  def isValidKernelId: Reads[Kernel.Id] = filter[Kernel.Id](JsonValidationError("Kernel IDs must be greater or equal to 1."))(
    x => x >= 1
  )
}
