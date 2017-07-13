package de.tu_darmstadt.cs.esa.tapasco.parser
import  de.tu_darmstadt.cs.esa.tapasco.base.Feature
import  fastparse.all._

private object FeatureParsers {
  import BasicParsers._
  def feature: Parser[Feature] =
    (qstring.opaque("feature name").! ~ ws ~/
     featureBegin ~ ws ~/
     (featureKeyValue ~ ws).rep ~ ws ~/
     featureEnd ~ ws)
        .map(p => Feature(p._1, p._2.toMap))

  def features: Parser[(String, Seq[Feature])] =
    longOption("features", "Features") ~ ws ~/ seqOne(feature)

  val featureBeginChars = "{(["
  val featureEndChars   = "})]"
  val featureMarks      = (featureBeginChars ++ featureEndChars) map (_.toString)
  val featureAssigns    = Seq("->", "=", ":=", ":")

  def featureBegin = CharIn(featureBeginChars).opaque(s"begin of feature mark, one of '$featureBeginChars'")
  def featureEnd   = CharIn(featureEndChars).opaque(s"end of feature mark, one of '$featureEndChars'")
  def featureAssign = "->" | "=" | ":=" | ":"

  def featureKey: Parser[String] =
    (quotedString | string(featureAssigns ++ featureMarks))
      .opaque("feature key name")

  def featureVal: Parser[String] =
    (quotedString | string(featureAssigns ++ featureMarks))
      .opaque("feature value for given key")

  def featureKeyValue: Parser[(String, String)] =
    featureKey ~ ws ~/
    featureAssign.opaque("feature assignment operator, one of '->', '=', ':=' or ':'") ~ ws ~/
    featureVal ~ ws
}
