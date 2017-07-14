package de.tu_darmstadt.cs.esa.tapasco.task

/** LogTracking instances maintain a list of relevant logfile paths. */
trait LogTracking {
  /** Returns a list of logfile paths. **/
  def logFiles: Set[String]
}
