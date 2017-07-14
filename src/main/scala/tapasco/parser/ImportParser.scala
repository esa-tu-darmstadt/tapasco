package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  fastparse.all._
import  java.nio.file.Path

private object ImportParser {
  import BasicParsers._
  import CommonArgParsers._

  def importzip: Parser[ImportJob] =
    (IgnoreCase("import") ~ ws ~/ zip ~ ws1 ~ IgnoreCase("as") ~ ws ~/ id ~ ws ~/ options ~ ws)
      .map { case (zip, id, optf) => optf(ImportJob(zipFile = zip, id = id)) }

  private def id: Parser[Kernel.Id] = posint.opaque("TaPaSCo function id, integer > 0")

  private def zip: Parser[Path] = path.opaque("path to .zip file containing IP-XACT core")

  private val jobid = identity[ImportJob] _

  private def options: Parser[ImportJob => ImportJob] =
    (description | avgClockCycles | architectures | platforms).rep map (opts =>
      (opts map (applyOption _) fold jobid) (_ andThen _))

  private def description: Parser[(String, String)] =
    longOption("description", "Description") ~ ws ~/ qstring.opaque("description text as string") ~ ws

  private def avgClockCycles: Parser[(String, Int)] =
    longOption("averageClockCycles", "AvgCC") ~ ws ~/
    posint.opaque("avg. number of clock cycles, integer > 0") ~ ws

  private def applyOption(opt: (String, _)): ImportJob => ImportJob = opt match {
    case ("Description", d: String) => _.copy(description = Some(d))
    case ("AvgCC", cc: Int) => _.copy(averageClockCycles = Some(cc))
    case ("Architectures", as: Seq[String @unchecked]) => _.copy(_architectures = Some(as))
    case ("Platforms", ps: Seq[String @unchecked]) => _.copy(_platforms = Some(ps))
    case o => throw new Exception(s"parsed illegal option: $o")
  }
}
