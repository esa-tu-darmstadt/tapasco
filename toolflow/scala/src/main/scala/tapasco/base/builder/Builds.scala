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
package tapasco.base.builder

import java.nio.file._

import play.api.libs.json._

import scala.io.Source

/**
  * The Builds trait simplifies file serializations in JSON format.
  * It provides methods to read and write from files and JsValue instances,
  * automatically handling any errors or exception by returning Eithers.
  * Each `to` requires an implicit `Writes[A]` or `Format[A]` instance, each
  * `from` an implicit `Reads[A]` or `Format[A]` instance (see the Play
  * json lib documentation for details).
  */
private[tapasco] trait Builds[A] {
  /**
    * Deserialize instance from a Json tree.
    *
    * @param json       Json tree.
    * @param sourcePath Path to source file (optional).
    * @param r          Reads[R] instance to parse Json (implicit).
    * @return Either the instance, or an exception detailing the error.
    **/
  def from(json: JsValue)(implicit sourcePath: Option[Path] = None, r: Reads[A]): Either[Throwable, A] =
    Json.fromJson[A](json) match {
      case s: JsSuccess[A] => Right(s.get)
      case e: JsError => Left(new Exception(e.toString))
    }

  /**
    * Deserialize instance from a Json file.
    *
    * @param p Path to source file.
    * @param r Reads[R] instance to parse Json (implicit).
    * @return Either the instance, or an exception detailing the error.
    **/
  def from(p: Path)(implicit r: Reads[A]): Either[Throwable, A] = try {
    //implicit val bp = new BasePathReads(p)
    val descPath = JsString(p.toAbsolutePath.normalize.toString)
    val pathTransformer = (JsPath \ "DescPath").json.put(descPath)
    from(Json.parse(
      // read from file
      Source.fromFile(p.toString).getLines.mkString)
      .transform(JsPath.json.update(pathTransformer)) // inject artificial key 'DescPath'
      .get
    )
  } catch {
    case e: Exception => Left(e)
  }

  /**
    * Serializes an instance to a Json tree.
    *
    * @param a Instance to serialize.
    * @param w Writes[A] instance to write Json (implicit).
    * @return Json tree.
    **/
  def to(a: A)(implicit w: Writes[A]): JsValue = Json.toJson(a)

  /**
    * Serializes an instance to file.
    *
    * @param a Instance to serialize.
    * @param p Path to destination file.
    * @param w Writes[A] instance to write Json (implicit).
    * @return Either true, of an exception detailing the error.
    **/
  def to(a: A, p: Path)(implicit w: Writes[A]): Either[Throwable, Boolean] = try {
    val fw = new java.io.FileWriter(p.toString)
    fw.append(Json.prettyPrint(to(a)))
    fw.close()
    Right(true)
  } catch {
    case e: java.io.IOException => Left(e)
  }
}
