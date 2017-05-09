package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher
import  scala.language.implicitConversions
import  java.nio.file.{Files, Path}

class BasePath(initialDir: Path, createOnSet: Boolean = true) extends Publisher {
  type Event = BasePath.Event
  private var path: Path = initialDir
  if (createOnSet) Files.createDirectories(initialDir)

  def apply: Path = path
  def get: Path   = path
  def set(p: Path): Unit = if (! p.equals(path)) {
    if (createOnSet) Files.createDirectories(p)
    path = p
    publish(BasePath.BasePathChanged(p))
  }
  override def toString(): String = path.toString()
}

object BasePath {
  sealed trait Event
  final case class BasePathChanged(path: Path) extends Event
  implicit def toPath(bp: BasePath): Path = bp.get
}
