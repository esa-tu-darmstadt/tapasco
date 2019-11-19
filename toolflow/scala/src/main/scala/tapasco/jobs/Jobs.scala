//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
package tapasco.jobs

import java.nio.file._

import tapasco.activity.composers._
import tapasco.activity.hls._
import tapasco.base._
import tapasco.base.builder._
import tapasco.dse._
import tapasco.filemgmt.FileAssetManager
import tapasco.jobs.executors.Executor
import tapasco.task._

/**
  * Abstract base class of jobs in TPC:
  * Every macro activity of TPC has its own Job structure, which contains the
  * arguments relevant to the activity. Each one has a Json represenation and
  * can be read and written to Json outputs.
  *
  * @param job String identifier of the job, e.g., "hls".
  **/
sealed abstract class Job(val job: String) {
  def execute(implicit exe: Executor[this.type], cfg: Configuration, tsk: Tasks): Boolean =
    exe.execute(this)(cfg, tsk)
}

/**
  * The BulkImport jobs imports a list of IP-XACT cores specified in a import
  * list (given as a comma-separated values [CSV] file).
  *
  * @param csvFile Path to CSV file.
  **/
final case class BulkImportJob(csvFile: Path) extends Job("bulkimport")

/**
  * The Compose job performs a single threadpool composition (i.e., synthesis
  * of a complete hardware architecture + bitstream generation). No design
  * space exploration is performed, the composition is attempted as-is with
  * a fixed design frequency. Composition is performed for each [[tapasco.base.Target]],
  * i.e., each combination of [[tapasco.base.Architecture]] and [[tapasco.base.Platform]] given.
  *
  * @param composition     Composition to synthesize micro-architecture for.
  * @param designFrequency Operating frequency of PEs in the design.
  * @param _implementation Composer Implementation (e.g., Vivado).
  * @param _architectures  Name list of [[tapasco.base.Architecture]] instances.
  * @param _platforms      Name list of [[tapasco.base.Platform]] instances.
  * @param features        List of [[tapasco.base.Feature]] configurations for the design (opt.).
  * @param debugMode       Debug mode name (opt.).
  * @param effortLevel     Synthesis effort level (opt.).
  **/
final case class ComposeJob(
                             composition: Composition,
                             designFrequency: Heuristics.Frequency,
                             private val _implementation: String,
                             private val _architectures: Option[Seq[String]] = None,
                             private val _platforms: Option[Seq[String]] = None,
                             features: Option[Seq[Feature]] = None,
                             debugMode: Option[String] = None,
                             effortLevel: Option[String] = None,
                             deleteProjects: Option[Boolean] = None) extends Job("compose") {
  /** Returns the selected composer tool implementation. */
  lazy val implementation: Composer.Implementation = Composer.Implementation(_implementation)

  /** Returns the list of [[tapasco.base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[tapasco.base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns a list of [[tapasco.base.Target]]s selected in this job. */
  def targets: Seq[Target] =
    for {a <- architectures.toSeq.sortBy(_.name); p <- platforms.toSeq.sortBy(_.name)} yield Target(a, p)
}

/**
  * The CoreStatistics job outputs a comma-separated values (CSV) file which
  * summarizes the synthesis results for each [[tapasco.base.Core]]. Data includes max.
  * operating frequency, area utilization and runtimes in clock cycles (if
  * available).
  *
  * @param prefix         Prefix for output file names: Each [[tapasco.base.Target]] generates a
  *                       separate output file; `prefix` may include paths.
  * @param _architectures Name list of [[tapasco.base.Architecture]] instances.
  * @param _platforms     Name list of [[tapasco.base.Platform]] instances.
  **/
final case class CoreStatisticsJob(
                                    prefix: Option[String] = None,
                                    private val _architectures: Option[Seq[String]] = None,
                                    private val _platforms: Option[Seq[String]] = None) extends Job("corestats") {
  /** Returns the list of [[tapasco.base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[tapasco.base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)
}

/**
  * The DesignSpaceExploration job launches a _design space exploration (DSE)_:
  * Starting from the `initialComposition`, the design is varied according to
  * the selected `dimensions`, e.g., if frequency variation is enabled, the
  * DSE will attempt to find the highest frequency where composition succeeds
  * (timing closure). The design space can be spanned with area utilization
  * (i.e., more instances of the [[tapasco.base.Core]]s), design frequency and alternatives
  * (i.e., switching between alternative implementations of a [[tapasco.base.Kernel]]).
  * This design space will be ordered by the selected [[tapasco.dse.Heuristics]]
  * implementation, which encodes an optimization goal (e.g., overall job
  * throughput, high area utilization, or others).
  * The DSE will the generate _batches of [[tapasco.jobs.ComposeJob]]s_ to iterate over the
  * design space with descending heuristics value and stop as soon as a
  * successful design was found. This design will be close to optimal w.r.t.
  * to given heuristic.
  *
  * @param initialComposition Composition to start with.
  * @param initialFrequency   Design frequency to start with.
  * @param dimensions         [[tapasco.dse.DesignSpace.Dimensions]] selected for this DSE.
  * @param heuristic          Heuristic function to order the design space by.
  * @param batchSize          Size of the batches (must be > 0).
  * @param basePath           Optional base path for all output files generated by DSE.
  * @param _architectures     Name filter for target [[tapasco.base.Architecture]]s (optional).
  * @param _platforms         Name filter for target [[tapasco.base.Platform]]s (optional).
  * @param features           List of [[tapasco.base.Feature]] configurations (optional).
  * @param debugMode          Debug mode name (opt.).
  **/
final case class DesignSpaceExplorationJob(
                                            initialComposition: Composition,
                                            initialFrequency: Option[Heuristics.Frequency],
                                            dimensions: DesignSpace.Dimensions,
                                            heuristic: Heuristics.Heuristic,
                                            batchSize: Option[Int],
                                            basePath: Option[Path] = None,
                                            private val _architectures: Option[Seq[String]] = None,
                                            private val _platforms: Option[Seq[String]] = None,
                                            features: Option[Seq[Feature]] = None,
                                            debugMode: Option[String] = None,
                                            deleteProjects: Option[Boolean] = None) extends Job("dse") {
  private final val logger = tapasco.Logging.logger(getClass)
  // warn if dimensions are completely empty
  dimensions match {
    case DesignSpace.Dimensions(false, false, false) =>
      logger.warn("no dimensions enabled in exploration job - consider using a compose job instead")
    case _ => ()
  }

  /** Returns the list of [[tapasco.base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the name filter for [[tapasco.base.Architecture]] instances. */
  def architectureNames: Option[Seq[String]] = _architectures

  /** Returns the list of [[tapasco.base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns the name filter for [[tapasco.base.Platform]] instances. */
  def platformNames: Option[Seq[String]] = _platforms

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
  * generate [[tapasco.base.Core]] instances from a [[tapasco.base.Kernel]] definition, which in turn can
  * then be used in composition of a threadpool. Will execute once for each
  * [[tapasco.base.Kernel]] and [[tapasco.base.Target]], i.e., each combination of [[tapasco.base.Platform]] and
  * [[tapasco.base.Architecture]] selected for the job.
  *
  * @param _implementation External tool to use, see [[tapasco.activity.hls.HighLevelSynthesizer.Implementation]].
  * @param _architectures  Name list of [[tapasco.base.Architecture]] instances.
  * @param _platforms      Name list of [[tapasco.base.Platform]] instances.
  * @param _kernels        Name list of [[tapasco.base.Kernel]] instances to synthesize.
  **/
final case class HighLevelSynthesisJob(
                                        private val _implementation: String,
                                        private val _architectures: Option[Seq[String]] = None,
                                        private val _platforms: Option[Seq[String]] = None,
                                        private val _kernels: Option[Seq[String]] = None,
                                        skipEvaluation: Option[Boolean] = None) extends Job("hls") {
  /** Returns the selected HLS tool implementation. */
  lazy val implementation: HighLevelSynthesizer.Implementation = HighLevelSynthesizer.Implementation(_implementation)

  /** Returns the list of [[tapasco.base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[tapasco.base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns the list of [[tapasco.base.Kernel]] instances selected in this job. */
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
  * The core will be imported for each [[tapasco.base.Target]], i.e., combination of
  * [[tapasco.base.Architecture]] and [[tapasco.base.Platform]] selected for this job.
  *
  * @param zipFile            Path to the .zip file.
  * @param id                 Identifier for the [[tapasco.base.Kernel]] that is implemented by this IP
  *                           core (must be > 0).
  * @param description        Description of the core (optional).
  * @param averageClockCycles Clock cycles in an average job (optional).
  * @param skipEvaluation     Do not perform evaluation (optional).
  * @param synthOptions       Optional parameters for synth_design.
  * @param _architectures     Name list of [[tapasco.base.Architecture]] instances.
  * @param _platforms         Name list of [[tapasco.base.Platform]] instances.
  * @param _optimization      Positive integer optimization level.
  **/
final case class ImportJob(
                            zipFile: Path,
                            id: Kernel.Id,
                            description: Option[String] = None,
                            averageClockCycles: Option[Long] = None,
                            skipEvaluation: Option[Boolean] = None,
                            synthOptions: Option[String] = None,
                            private val _architectures: Option[Seq[String]] = None,
                            private val _platforms: Option[Seq[String]] = None,
                            private val _optimization: Option[Int] = None) extends Job("import") {
  /** Returns the list of [[tapasco.base.Architecture]] instances selected in this job. */
  def architectures: Set[Architecture] =
    FileAssetManager.entities.architectures filter (a => _architectures map (_.contains(a.name)) getOrElse true)

  /** Returns the list of [[tapasco.base.Platform]] instances selected in this job. */
  def platforms: Set[Platform] =
    FileAssetManager.entities.platforms filter (p => _platforms map (_.contains(p.name)) getOrElse true)

  /** Returns the optimization level. */
  def optimization: Int = _optimization getOrElse 0
}

object BulkImportJob extends Builds[BulkImportJob]

object ComposeJob extends Builds[ComposeJob]

object CoreStatisticsJob extends Builds[CoreStatisticsJob]

object ImportJob extends Builds[ImportJob]

object HighLevelSynthesisJob extends Builds[HighLevelSynthesisJob]

object DesignSpaceExplorationJob extends Builds[DesignSpaceExplorationJob]

object Job extends Builds[Job]
