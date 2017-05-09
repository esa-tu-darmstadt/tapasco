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
    (JsPath \ "Kernels").readNullable[Seq[String]]
  ) (HighLevelSynthesisJob.apply _)

  implicit val highLevelSynthesisJobWrites: Writes[HighLevelSynthesisJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Implementation").write[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Kernels").writeNullable[Seq[String]]
  ) (unlift(HighLevelSynthesisJob.unapply _ andThen (_ map ("HighLevelSynthesis" +: _))))
  /* HighLevelSynthesisJob @} */

  /* @{ ImportJob */
  private val importJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "import")) ~>
    (JsPath \ "Zip").read[Path] ~
    (JsPath \ "Id").read[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Description").readNullable[String] ~
    (JsPath \ "Average Clock Cycles").readNullable[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]]
  ) (ImportJob.apply _)

  implicit val importJobWrites: Writes[ImportJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Zip").write[Path] ~
    (JsPath \ "Id").write[Int] ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "Average Clock Cycles").writeNullable[Int] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]]
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
    (JsPath \ "DebugMode").readNullable[String]
  ) (ComposeJob.apply _)

  implicit val composeJobWrites: Writes[ComposeJob] = (
    (JsPath \ "Job").write[String] ~
    (JsPath \ "Composition").write[Composition] ~
    (JsPath \ "Design Frequency").write[Heuristics.Frequency] ~
    (JsPath \ "Implementation").write[String] ~
    (JsPath \ "Architectures").writeNullable[Seq[String]] ~
    (JsPath \ "Platforms").writeNullable[Seq[String]] ~
    (JsPath \ "Features").writeNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").writeNullable[String]
  ) (unlift(ComposeJob.unapply _ andThen (_ map ("Compose" +: _))))
  /* ComposeJob @} */

  /* @{ DesignSpaceExplorationJob */
  private def atLeastOneVariation(d: DesignSpace.Dimensions): Boolean =
    d.frequency || d.utilization || d.alternatives
  private val dseJobReads: Reads[Job] = (
    (JsPath \ "Job").read[String] (verifying[String](_.toLowerCase equals "designspaceexploration")) ~>
    (JsPath \ "Initial Composition").read[Composition] ~
    (JsPath \ "Initial Frequency").readNullable[Heuristics.Frequency].map (_ getOrElse 100.0) ~
    (JsPath \ "Dimensions").read[DesignSpace.Dimensions] (verifying[DesignSpace.Dimensions](atLeastOneVariation _)) ~
    (JsPath \ "Heuristic").read[Heuristics.Heuristic] ~
    (JsPath \ "Batch Size").read[Int] (verifying[Int](_ > 0)) ~
    (JsPath \ "Output Path").readNullable[Path] ~
    (JsPath \ "Architectures").readNullable[Seq[String]] ~
    (JsPath \ "Platforms").readNullable[Seq[String]] ~
    (JsPath \ "Features").readNullable[Seq[Feature]] ~
    (JsPath \ "DebugMode").readNullable[String]
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
    (JsPath \ "DebugMode").writeNullable[String]
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
