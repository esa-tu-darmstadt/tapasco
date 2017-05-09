package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.sys.process._

/**
  * Utility class to query FlexLM license manager:
  * Queries FlexLM using 'lmstat -a' to get status information on available
  * licenses / features. If lmstat is not found, delivers default values.
  **/
object FlexLicenceManagerStatus {
  private[this] val _has_lmstat = "which lmstat".! == 0

  /**
   * Returns a map of license/features names to a pair of Ints representing
   * the total number of available licenses and the number of currently
   * checked out licenses. Will return empty map if lmstat is not available.
   * @return Feature name maps to (total licences, currently checked out)
   **/
  def licences: Map[String, (Int, Int)] = if (_has_lmstat) {
    try {
      (for (l <- ("lmstat -a" #| "grep Users").lineStream;
            m <- """Users\s*of\s*(\w+).*Total of (\d+) licenses issued;.*of (\d+) licenses in use""".r.findFirstMatchIn(l);
            e <- try   { Some(m.group(1) -> (m.group(2).toInt, m.group(3).toInt)) }
                 catch { case e: Exception => None }) yield e
      ).toMap
    } catch { case e: Exception => Map() }
  } else {
    Map()
  }

  /** Returns a pair of total number and number of currently checked out
   *  out licences for the given feature name. If lmstat is not available
   *  will return infinite number of licenses for every feature.
   **/
  def apply(feature: String): (Int, Int) = if (_has_lmstat) {
    licences getOrElse (feature, (0, 0))
  } else {
    (Integer.MAX_VALUE, 0) // bailout: just assume an infinite number of licenses
  }
}
