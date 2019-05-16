package de.tu_darmstadt.cs.esa.tapasco.reports

import java.nio.file.Path

final case class PortReport(override val file : Path, numSlaves : Int) extends Report(file)

object PortReport {

  def apply(pr : Path) : Option[PortReport] = Some(PortReport(pr, 42))
  // TODO Actually parse report after it was filled by the TCL script.

}
