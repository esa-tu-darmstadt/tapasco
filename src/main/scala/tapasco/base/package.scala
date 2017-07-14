package de.tu_darmstadt.cs.esa.tapasco
import  scala.language.implicitConversions

/**
 * Contains the basic entities and objects of Tapasco:
 * Definitions of [[Architecture]], [[Platform]], [[Kernel]], ...,
 * can be found here. These are the basic domain entities of TPC.
 **/
package object base {
  implicit def toTarget(td: TargetDesc): Target = Target.fromString(td.a, td.p).get
  implicit def toTargetDesc(t: Target): TargetDesc = TargetDesc(t.ad.name, t.pd.name)
}
