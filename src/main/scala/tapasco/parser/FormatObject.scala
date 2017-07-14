package de.tu_darmstadt.cs.esa.tapasco.parser
import  scala.language.implicitConversions

sealed trait FormatObject {
  def /(other: FormatObject)      = Concat(this, other)
  def concat(other: FormatObject) = Concat(this, other)
  def ~(other: FormatObject)      = Join(this, other)
  def join(other: FormatObject)   = Join(this, other)
  def &(other: FormatObject)      = Break(this, other)
  def break(other: FormatObject)  = Break(this, other)
}
final case class Header(title: String, section: ManSection, date: String, source: String) extends FormatObject
sealed class Section(val name: String, val content: FormatObject) extends FormatObject
object Section { def apply(name: String, content: FormatObject): FormatObject = new Section(name, content) }
final case class URL(url: String, text: String, trailer: String = "") extends FormatObject
final case class T(text: String) extends FormatObject

final case class Arg(arg: FormatObject, desc: FormatObject) extends FormatObject
final case class B(fo: FormatObject) extends FormatObject
final case class BI(fo: FormatObject) extends FormatObject
final case class BR(fo: FormatObject) extends FormatObject
final case class I(fo: FormatObject) extends FormatObject
final case class IB(fo: FormatObject) extends FormatObject
final case class IR(fo: FormatObject) extends FormatObject
final case class RB(fo: FormatObject) extends FormatObject
final case class RI(fo: FormatObject) extends FormatObject
final case class SB(fo: FormatObject) extends FormatObject
final case class SM(fo: FormatObject) extends FormatObject

final case class Block(fo: FormatObject, width: Int = 80) extends FormatObject
final case class Indent(fo: FormatObject, depth: Int = 2) extends FormatObject
final case class Concat(fo1: FormatObject, fo2: FormatObject) extends FormatObject
final case class Join(fo1: FormatObject, fo2: FormatObject) extends FormatObject
final case class Break(fo1: FormatObject, fo2: FormatObject) extends FormatObject

final case class Name(program: String, onelineDesc: String) extends Section("Name", T(s"$program - $onelineDesc"))
final case class Synopsis(shortUsage: FormatObject) extends Section("Synopsis", shortUsage)

object FormatObject {
  implicit def toFormatObject(s: String): FormatObject = T(s)
  implicit def toString(fo: FormatObject)(implicit formatter: Formatter[String]): String =
    formatter(fo)
}
