package de.tu_darmstadt.cs.esa.tapasco.jobs
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.task._

package object executors {
  trait Executor[-A] { def execute(a: A)(implicit cfg: Configuration, tsk: Tasks): Boolean }

  implicit final val BulkImportExecutor: Executor[BulkImportJob] = BulkImport
  implicit final val CoreStatisticsExecutor: Executor[CoreStatisticsJob] = CoreStatistics
  implicit final val ComposeExecutor: Executor[ComposeJob] = Compose
  implicit final val HighLevelSynthesisExecutor: Executor[HighLevelSynthesisJob] = HighLevelSynthesis
  implicit final val ImportExecutor: Executor[ImportJob] = Import
  implicit final val DesignSpaceExplorationExecutor: Executor[DesignSpaceExplorationJob] = DesignSpaceExploration

  def execute(j: Job)(implicit cfg: Configuration, tsk: Tasks): Boolean = j match {
    case cs: CoreStatisticsJob         => cs.execute
    case bi: BulkImportJob             => bi.execute
    case ce: ComposeJob                => ce.execute
    case hs: HighLevelSynthesisJob     => hs.execute
    case ij: ImportJob                 => ij.execute
    case ds: DesignSpaceExplorationJob => ds.execute
    case _ => throw new Exception("not implemented")
  }
}
