package de.tu_darmstadt.cs.esa.tapasco.activity.composers

/** Possible result kinds of composition runs. */
sealed trait ComposeResult

object ComposeResult {
  final case object Success extends ComposeResult
  final case object TimingFailure extends ComposeResult
  final case object Timeout extends ComposeResult
  final case object PlacerError extends ComposeResult
  final case object OtherError extends ComposeResult

  def apply(s: String): Option[ComposeResult] = s.toLowerCase match {
    case "success" => Some(Success)
    case "timingfailure" => Some(TimingFailure)
    case "timeout" => Some(Timeout)
    case "placererror" => Some(PlacerError)
    case "othererror" => Some(OtherError)
    case _ => None
  }
}
