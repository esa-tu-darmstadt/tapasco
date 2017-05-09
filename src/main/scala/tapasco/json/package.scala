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
