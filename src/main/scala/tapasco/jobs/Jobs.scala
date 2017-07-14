package de.tu_darmstadt.cs.esa.tapasco.jobs
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.base.builder._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.activity.hls._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  executors._
import  java.nio.file._

/**
 * Abstract base class of jobs in TPC:
 * Every macro activity of TPC has its own Job structure, which contains the
 * arguments relevant to the activity. Each one has a Json represenation and
 * can be read and written to Json outputs.
 * @param job String identifier of the job, e.g., "hls".
 **/
sealed abstract class Job(val job: String) {
  def execute(implicit exe: Executor[this.type], cfg: Configuration, tsk: Tasks): Boolean =
    exe.execute(this)(cfg, tsk)
}

/**
 * The BulkImport jobs imports a list of IP-XACT cores specified in a import
 * list (given as a comma-separated values [CSV] file).
 * @param csvFile Path to CSV file.
 **/
final case class BulkImportJob(csvFile: Path) extends Job("bulkimport")

/**
 * The Compose job performs a single threadpool composition (i.e., synthesis
 * of a complete hardware architecture + bitstream generation). No design
 * space exploration is performed, the composition is attempted as-is with
 * a fixed design frequency. Composition is performed for each [[base.Target]],
 * i.e., each combination of [[base.Architecture]] and [[base.Platform]] given.
 * @param composition Composition to synthesize micro-architecture for.
 * @param designFrequency Operating frequency of PEs in the design.
 * @param implementation Composer Implementation (e.g., Vivado).
 * @param _architectures Name list of [[base.Architecture]] instances.
 * @param _platforms Name list of [[base.Platform]] instances.
 * @param features List of [[base.Feature]] configurations for the design (opt.).
 * @param debugMode Debug mode name (opt.).
 **/
final case class ComposeJob(
    composition: Composition,
    designFrequency: Heuristics.Frequency,
    private val _implementation: String,
    private val _architectures: Option[Seq[String]] = None,
    private val _platforms: Option[Seq[String]] = None,
    features: Option[Seq[Feature]] = None,
    debugMode: Option[String] = None) extends Job("compose") {
  /** Returns the selected composer tool implementation. */
  lazy val implementation: Composer.Implementation = Composer.Implementation(_implementation)

  /** Returns the list of [[base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns a list of [[base.Target]]s selected in this job. */
  def targets: Seq[Target] =
    for { a <- architectures.toSeq.sortBy(_.name); p <- platforms.toSeq.sortBy(_.name) } yield Target(a, p)
}

/**
 * The CoreStatistics job outputs a comma-separated values (CSV) file which
 * summarizes the synthesis results for each [[base.Core]]. Data includes max.
 * operating frequency, area utilization and runtimes in clock cycles (if
 * available).
 * @param prefix Prefix for output file names: Each [[base.Target]] generates a
                 separate output file; `prefix` may include paths.
 * @param _architectures Name list of [[base.Architecture]] instances.
 * @param _platforms Name list of [[base.Platform]] instances.
 **/
final case class CoreStatisticsJob(
    prefix: Option[String] = None,
    private val _architectures: Option[Seq[String]] = None,
    private val _platforms: Option[Seq[String]] = None) extends Job("corestats") {
  /** Returns the list of [[base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)
}

/**
 * The DesignSpaceExploration job launches a _design space exploration (DSE)_:
 * Starting from the `initialComposition`, the design is varied according to
 * the selected `dimensions`, e.g., if frequency variation is enabled, the
 * DSE will attempt to find the highest frequency where composition succeeds
 * (timing closure). The design space can be spanned with area utilization
 * (i.e., more instances of the [[base.Core]]s), design frequency and alternatives
 * (i.e., switching between alternative implementations of a [[base.Kernel]]).
 * This design space will be ordered by the selected [[dse.Heuristics]]
 * implementation, which encodes an optimization goal (e.g., overall job
 * throughput, high area utilization, or others).
 * The DSE will the generate _batches of [[ComposeJob]]s_ to iterate over the
 * design space with descending heuristics value and stop as soon as a
 * successful design was found. This design will be close to optimal w.r.t.
 * to given heuristic.
 * @param initialComposition Composition to start with.
 * @param initialFrequency Design frequency to start with.
 * @param dimensions [[dse.DesignSpace.Dimensions]] selected for this DSE.
 * @param heuristic Heuristic function to order the design space by.
 * @param batchSize Size of the batches (must be > 0).
 * @param basePath Optional base path for all output files generated by DSE.
 * @param _architectures Name filter for target [[base.Architecture]]s (optional).
 * @param _platforms Name filter for target [[base.Platform]]s (optional).
 * @param features List of [[base.Feature]] configurations (optional).
 * @param debugMode Debug mode name (opt.).
 **/
final case class DesignSpaceExplorationJob(
    initialComposition: Composition,
    initialFrequency: Heuristics.Frequency,
    dimensions: DesignSpace.Dimensions,
    heuristic: Heuristics.Heuristic,
    batchSize: Int,
    basePath: Option[Path] = None,
    private val _architectures: Option[Seq[String]] = None,
    private val _platforms: Option[Seq[String]] = None,
    features: Option[Seq[Feature]] = None,
    debugMode: Option[String] = None) extends Job("dse") {
  /** Returns the list of [[base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the name filter for [[base.Architecture]] instances. */
  def architectureNames = _architectures

  /** Returns the list of [[base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns the name filter for [[base.Platform]] instances. */
  def platformNames = _platforms

  /** Returns the first target (alphabetically Arch - Platform). */
  def target: Target = targets.head

  /** Returns the list of target selected in this job. */
  def targets: Seq[Target] = for {
    a <- architectures.toSeq.sortBy(_.name)
    p <- platforms.toSeq.sortBy(_.name)
  } yield Target(a, p)
}

/**
 * The HighLevelSynthesis job executes an external high-level synthesis tool to
 * generate [[base.Core]] instances from a [[base.Kernel]] definition, which in turn can
 * then be used in composition of a threadpool. Will execute once for each
 * [[base.Kernel]] and [[base.Target]], i.e., each combination of [[base.Platform]] and
 * [[base.Architecture]] selected for the job.
 * @param _implementation External tool to use, see [[activity.hls.HighLevelSynthesizer.Implementation]].
 * @param _architectures Name list of [[base.Architecture]] instances.
 * @param _platforms Name list of [[base.Platform]] instances.
 * @param _kernels Name list of [[base.Kernel]] instances to synthesize.
 **/
final case class HighLevelSynthesisJob(
    private val _implementation: String,
    private val _architectures: Option[Seq[String]] = None,
    private val _platforms: Option[Seq[String]] = None,
    private val _kernels: Option[Seq[String]] = None) extends Job("hls") {
  /** Returns the selected HLS tool implementation. */
  lazy val implementation: HighLevelSynthesizer.Implementation = HighLevelSynthesizer.Implementation(_implementation)

  /** Returns the list of [[base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns the list of [[base.Kernel]] instances selected in this job. */
  def kernels: Set[Kernel] =
    FileAssetManager.entities.kernels filter (k => _kernels map (_.contains(k.name)) getOrElse true)
}

/**
 * The Import job takes an external IP-XACT IP core in a .zip file and imports
 * into the TPC library for use in compositions of threadpools. To facilitate
 * design space exploration, the core will be evaluated, i.e., out-of-context
 * synthesis + place-and-route will be performed to generate estimates for
 * area utilization and max. operating frequency. Optionally, average clock
 * cycle counts for a job execution can also be provided (otherwise 1 clock
 * cycle is assumed as a fallback). If reports are found within the .zip, or
 * in the TPC core library at the directory for the core, evaluation will be
 * skipped and the values from the reports will be used directly.
 * The core will be imported for each [[base.Target]], i.e., combination of
 * [[base.Architecture]] and [[base.Platform]] selected for this job.
 * @param zipFile Path to the .zip file.
 * @param id Identifier for the [[base.Kernel]] that is implemented by this IP
             core (must be > 0).
 * @param description Description of the core (optional).
 * @param averageClockCycles Clock cycles in an average job (optional).
 * @param _architectures Name list of [[base.Architecture]] instances.
 * @param _platforms Name list of [[base.Platform]] instances.
 **/
final case class ImportJob(
    zipFile: Path,
    id: Kernel.Id,
    description: Option[String] = None,
    averageClockCycles: Option[Int] = None,
    private val _architectures: Option[Seq[String]] = None,
    private val _platforms: Option[Seq[String]] = None) extends Job("import") {
  /** Returns the list of [[base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)
}

object BulkImportJob extends Builds[BulkImportJob]
object ComposeJob extends Builds[ComposeJob]
object CoreStatisticsJob extends Builds[CoreStatisticsJob]
object ImportJob extends Builds[ImportJob]
object HighLevelSynthesisJob extends Builds[HighLevelSynthesisJob]
object DesignSpaceExplorationJob extends Builds[DesignSpaceExplorationJob]
object Job extends Builds[Job]
