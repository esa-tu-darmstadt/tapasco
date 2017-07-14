package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.json._
import  play.api.libs.json._
import  play.api.libs.json.Reads._
import  play.api.libs.json.Writes._
import  play.api.libs.functional.syntax._
import  java.nio.file._
import  java.time.format.DateTimeFormatter, java.time.LocalDateTime

/**
 * The `json` package contains implicit Reads/Writes/Formats instances to serialize and
 * deserialize basic TPC entities to and from Json format.
 **/
package object json {
  private final val MAX_SLOTS = 128
  private def totalCountOk(c: Seq[Composition.Entry]): Boolean =
    (c map (_.count) fold 0) (_ + _) <= MAX_SLOTS

  /* @{ TargetDesc */
  implicit val targetReads: Reads[TargetDesc] = (
    (JsPath \ "Architecture").read[String] ~
    (JsPath \ "Platform").read[String]
  ) (TargetDesc.apply _)

  implicit val targetWrites: Writes[TargetDesc] = (
    (JsPath \ "Architecture").write[String] ~
    (JsPath \ "Platform").write[String]
  ) (unlift(TargetDesc.unapply _))
  /* TargetDesc @} */

  /* @{ Architecture */
  implicit val reads: Reads[Architecture] = (
    (JsPath \ "DescPath").readNullable[Path].map (_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "Name").read[String] ~
    (JsPath \ "TclLibrary").readNullable[Path].map (_ getOrElse Paths.get("test")) ~
    (JsPath \ "Description").readNullable[String].map (_ getOrElse "") ~
    (JsPath \ "ValueArgTemplate").readNullable[Path].map (_ getOrElse Paths.get("valuearg.directives.template")) ~
    (JsPath \ "ReferenceArgTemplate").readNullable[Path].map (_ getOrElse Paths.get("referencearg.directives.template")) ~
    (JsPath \ "AdditionalSteps").readNullable[Seq[String]].map (_ getOrElse Seq())
  ) (Architecture.apply _)
  implicit val writes: Writes[Architecture] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "Name").write[String] ~
    (JsPath \ "TclLibrary").write[Path] ~
    (JsPath \ "Description").write[String] ~
    (JsPath \ "ValueArgTemplate").write[Path] ~
    (JsPath \ "ReferenceArgTemplate").write[Path] ~
    (JsPath \ "AdditionalSteps").write[Seq[String]]
  ) (unlift(Architecture.unapply _))
  /* Architecture @}*/

  /* @{ Benchmark */
  private val dtf = DateTimeFormatter.ofPattern("yyyy-MM-d kk:mm:ss")

  implicit object FormatsLocalDateTime extends Format[LocalDateTime] {
    def reads(json: JsValue): JsResult[LocalDateTime] = json match {
      case JsString(s) => {
        try { JsSuccess(LocalDateTime.parse(s, dtf)) }
        catch { case e: Exception => JsError(Seq(JsPath() -> Seq(JsonValidationError("validation.error.expected.date")))) }
      }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("validation.error.expected.jsstring"))))
    }
    def writes(ldt: LocalDateTime): JsValue = JsString(dtf.format(ldt))
  }

  implicit val libraryVersionsFormat: Format[LibraryVersions] = (
      (JsPath \ "Platform API").format[String] ~
      (JsPath \ "Tapasco API").format[String]
    ) (LibraryVersions.apply _, unlift(LibraryVersions.unapply _))

  implicit val hostFormat: Format[Host] = (
      (JsPath \ "Machine").format[String] ~
      (JsPath \ "Node").format[String] ~
      (JsPath \ "Operating System").format[String] ~
      (JsPath \ "Release").format[String] ~
      (JsPath \ "Version").format[String]
    ) (Host.apply _, unlift(Host.unapply _))

  implicit val transferSpeedMeasurementFormat: Format[TransferSpeedMeasurement] = (
      (JsPath \ "Chunk Size").format[Long] ~
      (JsPath \ "Read").format[Double] ~
      (JsPath \ "Write").format[Double] ~
      (JsPath \ "ReadWrite").format[Double]
    ) (TransferSpeedMeasurement.apply _, unlift(TransferSpeedMeasurement.unapply _))

  implicit val interruptLatencyFormat: Format[InterruptLatency] = (
      (JsPath \ "Cycle Count").format[Long] ~
      (JsPath \ "Avg Latency").format[Double] ~
      (JsPath \ "Min Latency").format[Double] ~
      (JsPath \ "Max Latency").format[Double]
    ) (InterruptLatency.apply _, unlift(InterruptLatency.unapply _))

  implicit val jobThroughputFormat: Format[JobThroughput] = (
      (JsPath \ "Number of threads").format[Int] ~
      (JsPath \ "Jobs per second").format[Double]
    ) (JobThroughput.apply _, unlift(JobThroughput.unapply _))

  implicit val benchmarkReads: Reads[Benchmark] = (
      (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "Timestamp").read[LocalDateTime] ~
      (JsPath \ "Host").read[Host] ~
      (JsPath \ "Library Versions").read[LibraryVersions] ~
      (JsPath \ "Transfer Speed").read[Seq[TransferSpeedMeasurement]] ~
      (JsPath \ "Interrupt Latency").read[Seq[InterruptLatency]] ~
      (JsPath \ "Job Throughput").read[Seq[JobThroughput]]
    ) (Benchmark. apply _)
  implicit val benchmarkWrites: Writes[Benchmark] = (
      (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
      (JsPath \ "Timestamp").write[LocalDateTime] ~
      (JsPath \ "Host").write[Host] ~
      (JsPath \ "Library Versions").write[LibraryVersions] ~
      (JsPath \ "Transfer Speed").write[Seq[TransferSpeedMeasurement]] ~
      (JsPath \ "Interrupt Latency").write[Seq[InterruptLatency]] ~
      (JsPath \ "Job Throughput").write[Seq[JobThroughput]]
    ) (unlift(Benchmark.unapply _))
  /* Benchmark @} */

  /* @{ Composition.Entry */
  implicit val compositionEntryReads: Reads[Composition.Entry] = (
    (JsPath \ "Kernel").read[String] (minLength[String](1)) ~
    (JsPath \ "Count").read[Int] (min(1) keepAnd max(MAX_SLOTS))
  ) (Composition.Entry.apply _)

  implicit val compositionEntryWrites: Writes[Composition.Entry] = (
    (JsPath \ "Kernel").write[String] ~
    (JsPath \ "Count").write[Int]
  ) (unlift(Composition.Entry.unapply _))
  /* Composition.Entry @} */

  /* @{ Composition */
  implicit val compositionReads: Reads[Composition] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "Description").readNullable[String] ~
    (JsPath \ "Composition").read[Seq[Composition.Entry]]
      (/*minLength[Seq[Composition.Entry]](1) keepAnd*/
       verifying[Seq[Composition.Entry]](totalCountOk))
  ) (Composition.apply _)
  implicit val compositionWrites: Writes[Composition] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "Composition").write[Seq[Composition.Entry]]
  ) (unlift(Composition.unapply _))
  /* Composition @} */

  /* @{ Core */
  implicit val coreReads: Reads[Core] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "ZipFile").read[Path] ~
    (JsPath \ "Name").read[String] (minLength[String](1)) ~
    (JsPath \ "Id").read[Kernel.Id] (min(1)) ~
    (JsPath \ "Version").read[String] (minLength[String](1)) ~
    (JsPath \ "Target").read[TargetDesc] ~
    (JsPath \ "Description").readNullable[String] ~
    (JsPath \ "AverageClockCycles").readNullable[Int]
  ) (Core.apply _)
  implicit val coreWrites: Writes[Core] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "ZipFile").write[Path] ~
    (JsPath \ "Name").write[String] ~
    (JsPath \ "Id").write[Int] ~
    (JsPath \ "Version").write[String] ~
    (JsPath \ "Target").write[TargetDesc] ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "AverageClockCycles").writeNullable[Int]
  ) (unlift(Core.unapply _))
  /* Core @} */

  /* @{ Features */
  implicit val readsFeature: Reads[Feature] = (
    (JsPath \ "Feature").read[String] ~
    (JsPath \ "Properties").read[Map[String, String]]
  ) (Feature.apply _)

  implicit val writesFeature: Writes[Feature] = (
    (JsPath \ "Feature").write[String] ~
    (JsPath \ "Properties").write[Map[String, String]]
  ) (unlift(Feature.unapply _))
  /* Features @} */

  /* @{ Kernel.Argument */
  implicit object kernelPassingConventionFormat extends Format[Kernel.PassingConvention] {
    def reads(json: JsValue): JsResult[Kernel.PassingConvention] = json match {
      case JsString(str) => JsSuccess(Kernel.PassingConvention(str))
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.jsstring.for.passing.convention"))))
    }
    def writes(pc: Kernel.PassingConvention): JsValue = JsString(pc.toString)
  }
  implicit val kernelArgumentReads: Reads[Kernel.Argument] = (
    (JsPath \ "Name").read[String] (minLength[String](1)) ~
    (JsPath \ "Passing").readNullable[Kernel.PassingConvention].map (_ getOrElse Kernel.PassingConvention.ByValue)
  ) (Kernel.Argument.apply _)
  implicit val kernelArgumentWrites: Writes[Kernel.Argument] = (
    (JsPath \ "Name").write[String] ~
    (JsPath \ "Passing").write[Kernel.PassingConvention]
  ) (unlift(Kernel.Argument.unapply _))
  /* Kernel.Argument @} */

  /* @{ Kernel */
  implicit val kernelReads: Reads[Kernel] = (
    (JsPath \ "DescPath").readNullable[Path].map (_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "Name").read[String] (verifying[String](_.length > 0)) ~
    (JsPath \ "TopFunction").read[String] (verifying[String](_.length > 0)) ~
    (JsPath \ "Id").read[Kernel.Id] (verifying[Kernel.Id](_ > 0)) ~
    (JsPath \ "Version").read[String] (verifying[String](_.length > 0)) ~
    (JsPath \ "Files").read[Seq[Path]] (verifying[Seq[Path]](_.length > 0)) ~
    (JsPath \ "TestbenchFiles").readNullable[Seq[Path]].map (_ getOrElse Seq()) ~
    (JsPath \ "Description").readNullable[String] ~
    (JsPath \ "CompilerFlags").readNullable[Seq[String]].map (_ getOrElse Seq()) ~
    (JsPath \ "TestbenchCompilerFlags").readNullable[Seq[String]].map (_ getOrElse Seq()) ~
    (JsPath \ "Arguments").read[Seq[Kernel.Argument]] ~
    (JsPath \ "OtherDirectives").readNullable[Path]
  ) (Kernel.apply _)
  implicit val kernelWrites: Writes[Kernel] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "Name").write[String] ~
    (JsPath \ "TopFunction").write[String] ~
    (JsPath \ "Id").write[Int] ~
    (JsPath \ "Version").write[String] ~
    (JsPath \ "Files").write[Seq[Path]] ~
    (JsPath \ "TestbenchFiles").write[Seq[Path]] ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "CompilerFlags").write[Seq[String]] ~
    (JsPath \ "TestbenchCompilerFlags").write[Seq[String]] ~
    (JsPath \ "Arguments").write[Seq[Kernel.Argument]] ~
    (JsPath \ "OtherDirectives").writeNullable[Path]
  ) (unlift(Kernel.unapply _))
  /* Kernel @} */

  /* @{ Platform */
  // scalastyle:off magic.number
  implicit def platformReads: Reads[Platform] = (
    (JsPath \ "DescPath").readNullable[Path].map (_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "Name").read[String] (minLength[String](1)) ~
    (JsPath \ "TclLibrary").read[Path] ~
    (JsPath \ "Part").read[String] (minLength[String](1)) ~
    (JsPath \ "BoardPart").readNullable[String] (minLength[String](4)) ~
    (JsPath \ "BoardPreset").readNullable[String] (minLength[String](4)) ~
    (JsPath \ "TargetUtilization").read[Int] (min(5) keepAnd max(100)) ~
    (JsPath \ "SupportedFrequencies").readNullable[Seq[Int]] (minLength[Seq[Int]](1)) .map (_ getOrElse (50 to 450 by 5)) ~
    (JsPath \ "SlotCount").readNullable[Int] (min(1) keepAnd max(255)) ~
    (JsPath \ "Description").readNullable[String] (minLength[String](1)) ~
    (JsPath \ "Benchmark").readNullable[Path] ~
    (JsPath \ "HostFrequency").readNullable[Double] ~
    (JsPath \ "MemFrequency").readNullable[Double]
  ) (Platform.apply _)
  // scalastyle:on magic.number
  implicit def platformWrites: Writes[Platform] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "Name").write[String] ~
    (JsPath \ "TclLibrary").write[Path] ~
    (JsPath \ "Part").write[String] ~
    (JsPath \ "BoardPart").writeNullable[String] ~
    (JsPath \ "BoardPreset").writeNullable[String] ~
    (JsPath \ "TargetUtilization").write[Int] ~
    (JsPath \ "SupportedFrequencies").write[Seq[Int]] ~
    (JsPath \ "SlotCount").writeNullable[Int] ~
    (JsPath \ "Description").writeNullable[String] ~
    (JsPath \ "Benchmark").writeNullable[Path] ~
    (JsPath \ "HostFrequency").writeNullable[Double] ~
    (JsPath \ "MemFrequency").writeNullable[Double]
  ) (unlift(Platform.unapply _))
  /* Platform @} */

  /* @{ Configuration */
  implicit val configurationReads: Reads[Configuration] = (
    (JsPath \ "DescPath").readNullable[Path].map (_ getOrElse Paths.get("N/A")) ~
    (JsPath \ "ArchDir").readNullable[Path].map (_ getOrElse Paths.get("arch")) ~
    (JsPath \ "PlatformDir").readNullable[Path].map (_ getOrElse Paths.get("platform")) ~
    (JsPath \ "KernelDir").readNullable[Path].map (_ getOrElse Paths.get("kernel")) ~
    (JsPath \ "CoreDir").readNullable[Path].map (_ getOrElse Paths.get("core")) ~
    (JsPath \ "CompositionDir").readNullable[Path].map (_ getOrElse Paths.get("bd")) ~
    (JsPath \ "LogFile").readNullable[Path] ~
    (JsPath \ "Slurm").readNullable[Boolean].map (_ getOrElse false) ~
    (JsPath \ "Parallel").readNullable[Boolean].map (_ getOrElse false) ~
    (JsPath \ "MaxThreads").readNullable[Int] ~
    (JsPath \ "DryRun").readNullable[Path] ~
    (JsPath \ "Verbose").readNullable[String] ~
    (JsPath \ "Jobs").read[Seq[Job]]
  ) (ConfigurationImpl.apply _)
  implicit private val configurationWrites: Writes[ConfigurationImpl] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
    (JsPath \ "ArchDir").write[Path] ~
    (JsPath \ "PlatformDir").write[Path] ~
    (JsPath \ "KernelDir").write[Path] ~
    (JsPath \ "CoreDir").write[Path] ~
    (JsPath \ "CompositionDir").write[Path] ~
    (JsPath \ "LogFile").writeNullable[Path] ~
    (JsPath \ "Slurm").write[Boolean] ~
    (JsPath \ "Parallel").write[Boolean] ~
    (JsPath \ "MaxThreads").writeNullable[Int] ~
    (JsPath \ "DryRun").writeNullable[Path].transform((js: JsObject) => js - "DryRun") ~
    (JsPath \ "Verbose").writeNullable[String] ~
    (JsPath \ "Jobs").write[Seq[Job]]
  ) (unlift(ConfigurationImpl.unapply _))
  implicit object ConfigurationWrites extends Writes[Configuration] {
    def writes(c: Configuration): JsValue = c match {
      case ci: ConfigurationImpl => configurationWrites.writes(ci)
      case _ => throw new Exception("unknown Configuration implementation")
    }
  }
  /* Configuration @} */
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
