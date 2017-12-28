package de.tu_darmstadt.cs.esa.tapasco.jobs
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager

package object executors {
  trait Executor[-A] { def execute(a: A)(implicit cfg: Configuration, tsk: Tasks): Boolean }

  implicit final val BulkImportExecutor: Executor[BulkImportJob] = BulkImport
  implicit final val CoreStatisticsExecutor: Executor[CoreStatisticsJob] = CoreStatistics
  implicit final val ComposeExecutor: Executor[ComposeJob] = Compose
  implicit final val HighLevelSynthesisExecutor: Executor[HighLevelSynthesisJob] = HighLevelSynthesis
  implicit final val ImportExecutor: Executor[ImportJob] = Import
  implicit final val DesignSpaceExplorationExecutor: Executor[DesignSpaceExplorationJob] = DesignSpaceExploration

  def execute(j: Job)(implicit cfg: Configuration, tsk: Tasks, logger: Logger): Boolean = check(j) && (j match {
    case cs: CoreStatisticsJob         => cs.execute
    case bi: BulkImportJob             => bi.execute
    case ce: ComposeJob                => ce.execute
    case hs: HighLevelSynthesisJob     => hs.execute
    case ij: ImportJob                 => ij.execute
    case ds: DesignSpaceExplorationJob => ds.execute
    case _ => throw new Exception("not implemented")
  })

  private def checkPlatforms(j: { def platforms: Set[Platform] })(implicit logger: Logger) =
    if (j.platforms.isEmpty) {
      logger.error("no valid Platforms selected! (available: %s)".format(FileAssetManager.entities.platforms map (_.name) mkString ", "))
      false
    } else true

  private def checkArchs(j: { def architectures: Set[Architecture] })(implicit logger: Logger) =
    if (j.architectures.isEmpty) {
      logger.error("no valid Architectures selected! (available: %s)".format(FileAssetManager.entities.architectures map (_.name) mkString ", "))
      false
    } else true

  private def checkKernels(j: { def kernels: Set[Kernel] })(implicit logger: Logger) =
    if (j.kernels.isEmpty) {
      logger.error("no valid Kernels selected! (available: %s)".format(FileAssetManager.entities.kernels map (_.name) mkString ", "))
      false
    } else { logger.info(s"${j.kernels}"); true}

  def check(j: Job)(implicit cfg: Configuration, logger: Logger): Boolean = j match {
    case cj: ComposeJob => checkPlatforms(cj) && checkArchs(cj)
    case cj: CoreStatisticsJob => checkPlatforms(cj) && checkArchs(cj)
    case dj: DesignSpaceExplorationJob => checkPlatforms(dj) && checkArchs(dj)
    case hj: HighLevelSynthesisJob => checkPlatforms(hj) && checkArchs(hj) && checkKernels(hj)
    case ij: ImportJob => checkPlatforms(ij) && checkArchs(ij)
    case _ => true
  }
}
