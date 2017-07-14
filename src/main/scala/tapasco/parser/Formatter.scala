package de.tu_darmstadt.cs.esa.tapasco.parser
import  scala.util.Properties.{lineSeparator => NL}

/** Generic formatter for FormatObjects. */
trait Formatter[A] extends Function[FormatObject, A] {
  def format(header: Header): A
  def format(section: Section): A
  def format(url: URL): A
  def format(text: T): A
  def format(arg: Arg): A
  def format(b: B): A
  def format(bi: BI): A
  def format(br: BR): A
  def format(i: I): A
  def format(ib: IB): A
  def format(ir: IR): A
  def format(rb: RB): A
  def format(ri: RI): A
  def format(sb: SB): A
  def format(sb: SM): A
  def format(b: Block): A
  def format(in: Indent): A
  def format(p: Concat): A
  def format(p: Join): A
  def format(p: Break): A

  def apply(fo: FormatObject): A = fo match {
    case x: Header  => format(x)
    case x: Section => format(x)
    case x: URL     => format(x)
    case x: T       => format(x)
    case x: Arg     => format(x)
    case x: B       => format(x)
    case x: BI      => format(x)
    case x: BR      => format(x)
    case x: I       => format(x)
    case x: IB      => format(x)
    case x: IR      => format(x)
    case x: RB      => format(x)
    case x: RI      => format(x)
    case x: SB      => format(x)
    case x: SM      => format(x)
    case x: Block   => format(x)
    case x: Indent  => format(x)
    case x: Concat  => format(x)
    case x: Join    => format(x)
    case x: Break   => format(x)
  }
}

/** Formatter producing strings; used for CLI output. */
class StringFormatter extends Formatter[String] {
  protected val ARG_WIDTH = 80
  protected val ARG_LEFT  = 29
  protected val ARG_RIGHT = 50

  def isWhitespace(c: Char): Boolean = " \t\n".contains(c)

  private def wordwrap(s: String, line: String)(width: Int): Seq[String] = s.length match {
    case 0                         => Seq(line)
    case _ if line.length >= width => line +: wordwrap(s, "")(width)
    case _                         =>
      val rest = s.dropWhile(line.length == 0 && isWhitespace(_))
      val word = rest.takeWhile(c => if (isWhitespace(rest(0))) isWhitespace(c) else !isWhitespace(c))
      if (line.length + word.length > width) {
        line +: wordwrap(rest, "")(width)
      } else {
        wordwrap(s.drop(word.length), line ++ word)(width)
      }
  }

  def extend(l: String, width: Int): String = l ++ (" " * (width - l.length))

  def format(header: Header): String = ""
  def format(name: Name): String = s"${name.program} - ${name.onelineDesc}"
  def format(section: Section): String = "%s%s%s%s".format(NL, section.name.toUpperCase, NL, apply(Indent(section.content)))
  def format(url: URL): String = s"${url.url} ${url.trailer}"
  def format(t: T): String = t.text
  def format(a: Arg): String = {
    val l = apply(Block(a.arg, ARG_LEFT)).split(NL)
    val r = apply(Block(a.desc, ARG_RIGHT)).split(NL)
    val m = Seq(l.length, r.length).max
    val le = l ++ (0 until m - l.length map (_ => ""))
    val re = r ++ (0 until m - r.length map (_ => ""))
    (le zip re).map { case (l, r) => extend(l.take(ARG_LEFT), ARG_LEFT) ++ " " ++ r.take(ARG_RIGHT) }
               .mkString(NL)
  }
  def format(b: B): String = "**%s**".format(apply(b.fo))
  def format(bi: BI): String = apply(B(bi.fo))
  def format(br: BR): String = apply(B(br.fo))
  def format(i: I): String = "_%s_".format(apply(i.fo))
  def format(ib: IB): String = apply(I(B(ib.fo)))
  def format(ir: IR): String = apply(I(ir.fo))
  def format(rb: RB): String = apply(B(rb.fo))
  def format(ri: RI): String = apply(I(ri.fo))
  def format(sb: SB): String = apply(SM(sb.fo))
  def format(sb: SM): String = "%s".format(apply(sb.fo).toLowerCase)
  def format(b: Block): String = wordwrap(apply(b.fo), "")(b.width) mkString NL
  def format(in: Indent): String = apply(in.fo).split(NL).map(l => "%s%s".format(" " * in.depth, l)).mkString(NL)
  def format(p: Concat): String = Seq(apply(p.fo1), apply(p.fo2)) mkString
  def format(p: Join): String = Seq(apply(p.fo1), apply(p.fo2)) mkString " "
  def format(p: Break): String = Seq(apply(p.fo1), apply(p.fo2)).mkString(NL)
}

/** Formatter producing man page format. */
class ManPageFormatter extends StringFormatter {
  override def format(header: Header) =
    s".TH ${header.title} ${header.section: Int} ${header.source} ${header.section.manual}"

  override def format(section: Section): String =
    Seq(s".SH ${section.name.toUpperCase}",
        apply(section.content)) mkString NL

  override def format(indent: Indent): String =
    Seq(".RS", apply(indent.fo), ".RE") mkString NL

  override def format(a: Arg): String = apply(Indent(a.arg & Indent(a.desc)))

  override def format(b: B): String  = Seq(".B %s".format(apply(b.fo)), "") mkString NL
  override def format(b: BI): String = Seq(".BI %s".format(apply(b.fo)), "") mkString NL
  override def format(b: BR): String = Seq(".BR %s".format(apply(b.fo)), "") mkString NL
  override def format(i: I): String  = Seq(".I %s".format(apply(i.fo)), "") mkString NL
  override def format(i: IB): String = Seq(".IB %s".format(apply(i.fo)), "") mkString NL
  override def format(i: IR): String = Seq(".IR %s".format(apply(i.fo)), "") mkString NL
  override def format(r: RB): String = Seq(".RB %s".format(apply(r.fo)), "") mkString NL
  override def format(r: RI): String = Seq(".RI %s".format(apply(r.fo)), "") mkString NL
  override def format(s: SB): String = Seq(".SB %s".format(apply(s.fo)), "") mkString NL
  override def format(s: SM): String = Seq(".SM %s".format(apply(s.fo)), "") mkString NL

  override def format(t: T): String =
    super.format(t).replace("-", """\-""")
}

object StringFormatter extends StringFormatter
object ManPageFormatter extends ManPageFormatter
