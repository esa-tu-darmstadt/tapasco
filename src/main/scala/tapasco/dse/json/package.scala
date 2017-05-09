package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.Implicits._
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.Composer
import  de.tu_darmstadt.cs.esa.tapasco.activity.composers.json._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  de.tu_darmstadt.cs.esa.tapasco.util.json._
import  Exploration._
import  Exploration.Events._
import  Heuristics._
import  java.nio.file.Path
import  play.api.libs.json._
import  play.api.libs.functional.syntax._

// scalastyle:off null
package object json {
  /* @{ DesignSpace.Element */
  implicit val designSpaceElementFormat: Format[DesignSpace.Element] = (
    (JsPath \ "Composition").format[Composition] ~
    (JsPath \ "Frequency").format[Heuristics.Frequency] ~
    (JsPath \ "HeuristicValue").format[Heuristics.Value]
  ) (DesignSpace.Element.apply _, unlift(DesignSpace.Element.unapply _))
  /* DesignSpace.Element @} */

  /* @{ DesignSpace.Dimensions */
  implicit val designSpaceDimensionsFormat: Format[DesignSpace.Dimensions] = (
    (JsPath \ "Frequency").format[Boolean] ~
    (JsPath \ "Utilization").format[Boolean] ~
    (JsPath \ "Alternatives").format[Boolean]
  ) (DesignSpace.Dimensions.apply _, unlift(DesignSpace.Dimensions.unapply _))
  /* DesignSpace.Dimensions @} */

  /* @{ Heuristics.Heuristic */
  implicit object HeuristicsFormat extends Format[Heuristics.Heuristic] {
    def reads(json: JsValue): JsResult[Heuristics.Heuristic] = json match {
      case JsString(str) => str.toLowerCase match {
        case "job throughput" => JsSuccess(ThroughputHeuristic)
        case h => JsError(Seq(JsPath() -> Seq(JsonValidationError("unknown.heuristic.%s".format(h)))))
      }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.string.for.heuristic"))))
    }
    def writes(h: Heuristics.Heuristic): JsValue = h match {
      case ThroughputHeuristic => JsString("Job Throughput")
      case _ => JsString(h.toString)
    }
  }
  /* Heuristics.Heuristic @} */

  /* @{ PruningReason */
  implicit val pruningReasonFormat = new Format[PruningReason] {
    def reads(json: JsValue): JsResult[PruningReason] = json match {
      case JsString(str) => PruningReason(str) map (JsSuccess(_)) getOrElse
        JsError(Seq(JsPath() -> Seq(JsonValidationError("invalid.pruning.reason.%s".format(str)))))
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.pruning.reason"))))
    }
    def writes(reason: PruningReason): JsValue = JsString(reason.toString)
  }
  /* PruningReason @} */

  /* @{ RunDefined */
  val runDefinedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "RunDefined")) ~>
    (JsPath \ "Element").read[DesignSpace.Element] ~
    (JsPath \ "Utilization").read[AreaEstimate]
  ) (RunDefined.apply _)

  implicit val runDefinedWrites: Writes[RunDefined] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Element").write[DesignSpace.Element] ~
    (JsPath \ "Utilization").write[AreaEstimate]
  ) (unlift(RunDefined.unapply _ andThen (_ map ("RunDefined" +: _))))
  /* RunDefined @} */

  /* @{ RunStarted */
  private def mkRunStarted(e: DesignSpace.Element) = RunStarted(e, null)

  val runStartedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "RunStarted")) ~>
    (JsPath \ "Element").read[DesignSpace.Element]
  ) fmap (mkRunStarted _)

  private def wrRunStarted(e: RunStarted) = ("RunStarted", e.element)

  implicit val runStartedWrites: Writes[RunStarted] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Element").write[DesignSpace.Element]
  ) (wrRunStarted _)
  /* RunStarted @} */

  /* @{ RunFinished */
  private def mkRunFinished(e: DesignSpace.Element) = RunFinished(e, null)

  val runFinishedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "RunFinished")) ~>
    (JsPath \ "Element").read[DesignSpace.Element]
  ) fmap (mkRunFinished _)

  private def wrRunFinished(e: RunFinished) = ("RunFinished", e.element, e.task.composerResult)

  implicit val runFinishedWrites: Writes[RunFinished] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Element").write[DesignSpace.Element] ~
    (JsPath \ "Result").writeNullable[Composer.Result]
  ) (wrRunFinished _)
  /* RunFinished @} */

  /* @{ RunGenerated */
  val runGeneratedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "RunGenerated")) ~>
    (JsPath \ "From").read[DesignSpace.Element] ~
    (JsPath \ "Element").read[DesignSpace.Element] ~
    (JsPath \ "Utilization").read[AreaEstimate]
  ) (RunGenerated.apply _)

  private def wrRunGenerated(e: RunGenerated) = (
    "RunGenerated",
    e.element,
    e.from,
    e.utilization
  )

  implicit val runGeneratedWrites: Writes[RunGenerated] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Element").write[DesignSpace.Element] ~
    (JsPath \ "From").write[DesignSpace.Element] ~
    (JsPath \ "Utilization").write[AreaEstimate]
  ) (wrRunGenerated _)
  /* RunGenerated @} */

  /* @{ RunPruned */
  val runPrunedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "RunPruned")) ~>
    (JsPath \ "Elements").read[Seq[DesignSpace.Element]] (Reads.minLength[Seq[DesignSpace.Element]](1)) ~
    (JsPath \ "Cause").read[DesignSpace.Element] ~
    (JsPath \ "Reason").read[PruningReason]
  ) (RunPruned.apply _)

  private def wrRunPruned(e: RunPruned) = (
    "RunPruned",
    e.elements,
    e.cause,
    e.reason
  )

  implicit val runPrunedWrites: Writes[RunPruned] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Elements").write[Seq[DesignSpace.Element]] ~
    (JsPath \ "Cause").write[DesignSpace.Element] ~
    (JsPath \ "Reason").write[PruningReason]
  ) (wrRunPruned _)
  /* RunPruned @} */

  /* @{ BatchStarted */
  val batchStartedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "BatchStarted")) ~>
    (JsPath \ "Number").read[Int] ~
    (JsPath \ "Elements").read[Seq[DesignSpace.Element]] (Reads.minLength[Seq[DesignSpace.Element]](1))
  ) (BatchStarted.apply _)

  private def wrBatchStarted(e: BatchStarted) = ("BatchStarted", e.batchNumber, e.elements)

  implicit val batchStartedWrites: Writes[BatchStarted] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Number").write[Int] ~
    (JsPath \ "Elements").write[Seq[DesignSpace.Element]]
  ) (wrBatchStarted _)
  /* BatchStarted @} */

  /* @{ BatchFinished */
  val batchFinishedReads: Reads[Exploration.Event] = (
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "BatchFinished")) ~>
    (JsPath \ "Number").read[Int] ~
    (JsPath \ "Elements").read[Seq[DesignSpace.Element]] (Reads.minLength[Seq[DesignSpace.Element]](1)) ~
    (JsPath \ "Results").read[Seq[Composer.Result]] (Reads.minLength[Seq[Composer.Result]](1))
  ) (BatchFinished.apply _)

  private def wrBatchFinished(e: BatchFinished) = ("BatchFinished", e.batchNumber, e.elements, e.results)

  implicit val batchFinishedWrites: Writes[BatchFinished] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Number").write[Int] ~
    (JsPath \ "Elements").write[Seq[DesignSpace.Element]] ~
    (JsPath \ "Results").write[Seq[Composer.Result]]
  ) (wrBatchFinished _)
  /* BatchFinished @} */

  /* @{ ExplorationStarted */
  val explorationStartedReads: Reads[Exploration.Event] =
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "ExplorationStarted"))
      .fmap (_ => ExplorationStarted(null))

  private def wrExplorationStarted(e: ExplorationStarted) = (
    "ExplorationStarted",
    e.ex.initialComposition,
    e.ex.target: TargetDesc,
    e.ex.designFrequency,
    e.ex.dimensions,
    e.ex.batchSize,
    e.ex.configuration,
    e.ex.basePath
  )

  implicit val explorationStartedWrites: Writes[ExplorationStarted] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "Initial Composition").write[Composition] ~
    (JsPath \ "Target").write[TargetDesc] ~
    (JsPath \ "Initial Frequency").write[Heuristics.Frequency] ~
    (JsPath \ "Dimensions").write[DesignSpace.Dimensions] ~
    (JsPath \ "BatchSize").write[Int] ~
    (JsPath \ "Configuration").write[Configuration] ~
    (JsPath \ "Base Path").write[Path]
  ) (wrExplorationStarted _)
  /* ExplorationStarted @} */

  /* @{ ExplorationFinished */
  val explorationFinishedReads: Reads[Exploration.Event] =
    (JsPath \ "Kind").read[String](Reads.verifying[String](_ equals "ExplorationFinished"))
      .fmap (_ => ExplorationFinished(null))

  private def wrExplorationFinished(e: ExplorationFinished) = (
    "ExplorationFinished",
    e.ex.initialComposition,
    e.ex.target: TargetDesc,
    e.ex.designFrequency,
    e.ex.dimensions,
    e.ex.batchSize,
    e.ex.configuration,
    e.ex.basePath,
    e.ex.result map (_._1),
    e.ex.result map (_._2)
  )

  implicit val explorationFinishedWrites: Writes[ExplorationFinished] = (
    (JsPath \ "Kind").write[String] ~
    (JsPath \ "InitialComposition").write[Composition] ~
    (JsPath \ "Target").write[TargetDesc] ~
    (JsPath \ "Initial Frequency").write[Heuristics.Frequency] ~
    (JsPath \ "Dimensions").write[DesignSpace.Dimensions] ~
    (JsPath \ "BatchSize").write[Int] ~
    (JsPath \ "Configuration").write[Configuration] ~
    (JsPath \ "Base Path").write[Path] ~
    (JsPath \ "Element").writeNullable[DesignSpace.Element] ~
    (JsPath \ "Result").writeNullable[Composer.Result]
  ) (wrExplorationFinished _)
  /* ExplorationFinished @} */

  /* @{ Events SerDes */
  val eventReads: Reads[Exploration.Event] =
    runDefinedReads | runStartedReads | runFinishedReads | runGeneratedReads | runPrunedReads |
    batchStartedReads | batchFinishedReads |
    explorationStartedReads | explorationFinishedReads

  val eventWrites = new Writes[Exploration.Event] {
    def writes(e: Exploration.Event): JsValue = e match {
      case ce: RunDefined          => Json.toJson(ce)
      case ce: RunStarted          => Json.toJson(ce)
      case ce: RunFinished         => Json.toJson(ce)
      case ce: RunGenerated        => Json.toJson(ce)
      case ce: RunPruned           => Json.toJson(ce)
      case ce: BatchStarted        => Json.toJson(ce)
      case ce: BatchFinished       => Json.toJson(ce)
      case ce: ExplorationStarted  => Json.toJson(ce)
      case ce: ExplorationFinished => Json.toJson(ce)
    }
  }

  implicit val eventFormat = new Format[Exploration.Event] {
    def reads(json: JsValue): JsResult[Exploration.Event] = eventReads.reads(json)
    def writes(e: Exploration.Event): JsValue = eventWrites.writes(e)
  }
  /* @} */
}
// scalastyle:on null
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
