package de.tu_darmstadt.cs.esa.tapasco.parser
import  scala.language.implicitConversions

sealed abstract class ManSection(private val n: Int, _manual: Option[String] = None) {
  require(n > 0 && n <= 9, "invalid section number, use 1-9")
  lazy val manual: String = _manual getOrElse "MAN(%d)".format(n)
}

final case object GeneralCommands extends ManSection(1)
final case object SystemCalls extends ManSection(2)
final case object LibraryFunctions extends ManSection(3)
final case object SpecialFiles extends ManSection(4)
final case object FileFormatsConventions extends ManSection(5)
final case object GamesAndScreensavers extends ManSection(6)
final case object Miscellanea extends ManSection(7)
final case object SysAdminCommands extends ManSection(8)

object ManSection {
  private lazy val numMap: Map[Int, ManSection] = all map (s => (s: Int) -> s) toMap

  lazy val all: Seq[ManSection] = Seq(
    GeneralCommands,
    SystemCalls,
    LibraryFunctions,
    SpecialFiles,
    FileFormatsConventions,
    GamesAndScreensavers,
    Miscellanea,
    SysAdminCommands
  )

  def apply(n: Int) = numMap(n)

  implicit def toManSection(n: Int): ManSection = apply(n)
  implicit def toInt(s: ManSection): Int        = s.n
}
