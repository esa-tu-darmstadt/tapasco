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
package de.tu_darmstadt.cs.esa.tapasco.jobs
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.Logging._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager

// scalastyle:off structural.type
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
    j.platforms.nonEmpty || {
      logger.error("no valid Platforms selected! (available: %s)".format(FileAssetManager.entities.platforms map (_.name) mkString ", "))
      false
    }

  private def checkArchs(j: { def architectures: Set[Architecture] })(implicit logger: Logger) =
    j.architectures.nonEmpty || {
      logger.error("no valid Architectures selected! (available: %s)".format(FileAssetManager.entities.architectures map (_.name) mkString ", "))
      false
    }

  private def checkKernels(j: { def kernels: Set[Kernel] })(implicit logger: Logger) =
    j.kernels.nonEmpty || {
      logger.error("no valid Kernels selected! (available: %s)".format(FileAssetManager.entities.kernels map (_.name) mkString ", "))
      false
    }

  // scalastyle:off cyclomatic.complexity
  def check(j: Job)(implicit cfg: Configuration, logger: Logger): Boolean = j match {
    case cj: ComposeJob => checkPlatforms(cj) && checkArchs(cj)
    case cj: CoreStatisticsJob => checkPlatforms(cj) && checkArchs(cj)
    case dj: DesignSpaceExplorationJob => checkPlatforms(dj) && checkArchs(dj)
    case hj: HighLevelSynthesisJob => checkPlatforms(hj) && checkArchs(hj) && checkKernels(hj)
    case ij: ImportJob => checkPlatforms(ij) && checkArchs(ij)
    case _ => true
  }
  // scalastyle:on cyclomatic.complexity
}
// scalastyle:on structural.type
