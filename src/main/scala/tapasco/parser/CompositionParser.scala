package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  java.nio.file.Paths

private object CompositionParser {
  import CommandLineParser._

  /** Returns a parser for a [[Composition]]. */
  def apply(): Parser[Composition] = composition

  /* @{ Composition */
  private def compositionEntry: Parser[Composition.Entry] =
    (ident ~ "x" ~ wholeNumber) ^^ { p => Composition.Entry(p._1._1, p._2.toInt) }

  private def composition: Parser[Composition] = (
    (param("composition", false) ~> "[" ~> rep1sep(compositionEntry, LIST_SEP) ~ "]") ^^ { p => Composition(
      Paths.get("N/A"),
      None,
      p._1)} |
    (param("composition", false) ~> path) ^^ { p => Composition.from(Paths.get(p)).toTry.get }
  )
  /* Composition @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
