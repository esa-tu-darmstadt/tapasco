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
import  de.tu_darmstadt.cs.esa.tapasco.Implicits._
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.dse.json._
import  play.api.libs.json._
import  play.api.libs.json.Reads._
import  play.api.libs.functional.syntax._
import  java.nio.file._

package object json {
  /* @{ HighLevelSynthesisJob */
  private val highLevelSynthesisJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "highlevelsynthesis")) ~>
    (JsPath \ "Implementation").readNullable[String].map (_ getOrElse "VivadoHLS") ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]] ~
    (JsPath \ "Kernels").readNullable[Seq[String]] ~
    (JsPath \ "Skip Evaluation").readNullable[Boolean]
  ) (HighLevelSynthesisJob.apply _)

  implicit val highLevelSynthesisJobWrites: Writes[HighLevelSynthesisJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Implementation").write[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Kernels").writeNullable[Seq[String]] ~
      (JsPath \ "Skip Evaluation").writeNullable[Boolean]
  ) (unlift(HighLevelSynthesisJob.unapply _ andThen (_ map ("HighLevelSynthesis" +: _))))
  /* HighLevelSynthesisJob @} */

  /* @{ ImportJob */
  private val importJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "import")) ~>
    (JsPath \ "Zip").read[Path] ~
    (JsPath \ "Id").read[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Description").readNullable[String] ~
    (JsPath \ "Average Clock Cycles").readNullable[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Skip Evaluation").readNullable[Boolean] ~
    (JsPath \ "Synth Options").readNullable[String] ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]] ~
    (JsPath \ "Optimization").readNullable[Int] (verifying[Int](_ >= 0))
  ) (ImportJob.apply _)

  implicit val importJobWrites: Writes[ImportJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Zip").write[Path] ~
    (JsPath \ "Id").write[Int] ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "Average Clock Cycles").writeNullable[Int] ~
    (JsPath \ "Skip Evaluation").writeNullable[Boolean] ~
    (JsPath \ "Synth Options").writeNullable[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Optimization").writeNullable[Int]
  ) (unlift(ImportJob.unapply _ andThen (_ map ("Import" +: _))))
  /* ImportJob @} */

  /* @{ BulkImportJob */
  private val bulkImportJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "bulkimport")) ~>
    (JsPath \ "CSV").read[Path]
  ) .fmap(BulkImportJob.apply _)

  implicit val bulkImportJobWrites: Writes[BulkImportJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "CSV").write[Path]
  ) (unlift(BulkImportJob.unapply _ andThen (_ map (("BulkImport", _)))))
  /* BulkImportJob @} */

  /* @{ CoreStatisticsJob */
  private val coreStatisticsJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "corestatistics")) ~>
    (JsPath \ "File Prefix").readNullable[String] ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]]
  ) (CoreStatisticsJob.apply _)

  implicit val coreStatisticsJobWrites: Writes[CoreStatisticsJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "File Prefix").writeNullable[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]]
  ) (unlift(CoreStatisticsJob.unapply _ andThen (_ map ("CoreStatistics" +: _))))
  /* CoreStatisticsJob @} */

  /* @{ ComposeJob */
  private val composeJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "compose")) ~>
    ((JsPath \ "Composition").read[Composition] | (JsPath \ "Composition").read[Path].map {
      p => Composition.from(p).toTry.get
    }) ~
    (JsPath \ "Design Frequency").read[Heuristics.Frequency] (verifying[Heuristics.Frequency](f => f >= 50 && f <= 500)) ~
    (JsPath \ "Implementation").readNullable[String].map (_ getOrElse "Vivado") ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]] ~
    (JsPath \ "Features").readNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").readNullable[String] ~
    (JsPath \ "DeleteProjects").readNullable[Boolean]
  ) (ComposeJob.apply _)

  implicit val composeJobWrites: Writes[ComposeJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Composition").write[Composition] ~
    (JsPath \ "Design Frequency").write[Heuristics.Frequency] ~
    (JsPath \ "Implementation").write[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Features").writeNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").writeNullable[String] ~
    (JsPath \ "DeleteProjects").writeNullable[Boolean]
  ) (unlift(ComposeJob.unapply _ andThen (_ map ("Compose" +: _))))
  /* ComposeJob @} */

  /* @{ DesignSpaceExplorationJob */
  private val dseJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "designspaceexploration")) ~>
    (JsPath \ "Initial Composition").read[Composition] ~
    (JsPath \ "Initial Frequency").readNullable[Heuristics.Frequency].map (_ getOrElse 100.0) ~
    (JsPath \ "Dimensions").read[DesignSpace.Dimensions] ~
    (JsPath \ "Heuristic").read[Heuristics.Heuristic] ~
    (JsPath \ "Batch Size").read[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Output Path").readNullable[Path] ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]] ~
    (JsPath \ "Features").readNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").readNullable[String] ~
    (JsPath \ "DeleteProjects").readNullable[Boolean]
  ) (DesignSpaceExplorationJob.apply _)

  implicit val dseJobWrites: Writes[DesignSpaceExplorationJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Initial Composition").write[Composition] ~
    (JsPath \ "Initial Frequency").write[Heuristics.Frequency] ~
    (JsPath \ "Dimensions").write[DesignSpace.Dimensions] ~
    (JsPath \ "Heuristic").write[Heuristics.Heuristic] ~
    (JsPath \ "Batch Size").write[Int] ~
    (JsPath \ "Output Path").writeNullable[Path] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Features").writeNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").writeNullable[String] ~
    (JsPath \ "DeleteProjects").writeNullable[Boolean]
  ) (unlift(DesignSpaceExplorationJob.unapply _ andThen (_ map ("DesignSpaceExploration" +: _))))
  /* DesignSpaceExplorationJob @} */

  /* @{ Job */
  implicit val jobReads: Reads[Job] =
    highLevelSynthesisJobReads | importJobReads | bulkImportJobReads | coreStatisticsJobReads |
    composeJobReads | dseJobReads | JsPath.read[Path].map(p => Job.from(p).toTry.get)

  implicit object jobWrites extends Writes[Job] {
    def writes(j: Job): JsValue = j match { // TODO fix this; how to properly dump families in collections?
      case t: BulkImportJob             => bulkImportJobWrites.writes(t)
      case t: ComposeJob                => composeJobWrites.writes(t)
      case t: CoreStatisticsJob         => coreStatisticsJobWrites.writes(t)
      case t: DesignSpaceExplorationJob => dseJobWrites.writes(t)
      case t: HighLevelSynthesisJob     => highLevelSynthesisJobWrites.writes(t)
      case t: ImportJob                 => importJobWrites.writes(t)
    }
  }
  /* Job @} */
}
// vim: foldmethod=marker foldmarker=@{,@} foldlevel=0
