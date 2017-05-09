package de.tu_darmstadt.cs.esa.tapasco.activity.hls
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  java.nio.file.Path

/** A HighLevelSynthesizer produces a [[base.Core]] from a [[base.Kernel]] description.
  * It synthesizes a reusable hardware module for a given [[base.Kernel]].
  **/
trait HighLevelSynthesizer {
  import HighLevelSynthesizer._
  /** Returns the path to the main log file.
    * @param k Kernel.
    * @param t Target (Architecture + Platform).
    * @param cfg Implicit Configuration.
    * @return Path to log file of this synthesis run.
    **/
  def logFile(k: Kernel, t: Target)(implicit cfg: Configuration): Path =
    cfg.outputDir(k, t).resolve("hls").resolve("%s.log".format(t.ad.name))
  /** Returns the path to the output .zip file.
    * @param k Kernel.
    * @param t Target (Architecture + Platform).
    * @param cfg Implicit Configuration.
    * @return Path to .zip file of this synthesis run.
    **/
  def outputZipFile(k: Kernel, t: Target)(implicit cfg: Configuration): Path =
    cfg.outputDir(k, t).resolve("ipcore").resolve("%s_%s.zip".format(k.name, t.ad.name))

  /** Starts a synthesis run.
    * @param k Kernel.
    * @param t Target (Architecture + Platform).
    * @param cfg Implicit Configuration.
    * @return result of the synthesis run.
    **/
  def synthesize(k: Kernel, target: Target)(implicit cfg: Configuration): Result

  /** Removes all intermediate files for the run.
    * @param k Kernel.
    * @param t Target (Architecture + Platform).
    * @param cfg Implicit Configuration.
    **/
  def clean(k: Kernel, target: Target)(implicit cfg: Configuration): Unit

  /** Removes all output files for the run.
    * @param k Kernel.
    * @param t Target (Architecture + Platform).
    * @param cfg Implicit Configuration.
    **/
  def cleanAll(k: Kernel, target: Target)(implicit cfg: Configuration): Unit
}

/** Factory for HighLevelSynthesizer instances. */
object HighLevelSynthesizer {
  /** HighLevelSynthesizer implementation. */
  sealed trait Implementation
  /** Contains all implementations of HighLevelSynthesizer. */
  object Implementation {
    /** Vivado HLS. */
    final case object VivadoHLS extends Implementation
    /** Construct Implementation instance from String.
      * @param name String containing name of implementation.
      * @returns Implementation instance, or throws exception.
      * @throws java.lang.Exception in case the name could not be matched.
      **/
    def apply(name: String): Implementation = name.toLowerCase match {
      case "vivadohls" => Implementation.VivadoHLS
      case _           => throw new Exception("unknown HLS implementation: '%s'".format(name))
    }
  }

  /** Construct a [[HighLevelSynthesizer]] from [[Implementation]]. */
  def apply(i: Implementation): HighLevelSynthesizer = i match {
    case Implementation.VivadoHLS => VivadoHighLevelSynthesis
  }

  /** Result of a HLS run. */
  sealed trait Result {
    /** Log file. */
    def log: HighLevelSynthesizerLog
    /** Basic result: true if successful, false otherwise. */
    def toBoolean: Boolean = false
  }
  /** Successful HLS run. */
  final case class Success(log: HighLevelSynthesizerLog, zip: Path) extends Result {
    override def toBoolean: Boolean = true
  }
  /** HLS run that failed due to a exceptionally long runtime. */
  final case class Timeout(log: HighLevelSynthesizerLog) extends Result
  /** HLS run that failed with non-zero return code. */
  final case class VivadoError(log: HighLevelSynthesizerLog, returnCode: Int) extends Result
  /** HLS run that failed due to another kind of error. */
  final case class OtherError(log: HighLevelSynthesizerLog, e: Exception) extends Result
}

