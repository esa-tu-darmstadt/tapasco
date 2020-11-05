/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
package tapasco.base

import java.nio.file._
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

import play.api.libs.functional.syntax._
import play.api.libs.json.Reads._
import play.api.libs.json.Writes._
import play.api.libs.json._
import tapasco.PLATFORM_NUM_SLOTS
import tapasco.filemgmt.BasePathManager
import tapasco.jobs.Job
import tapasco.jobs.json._
import tapasco.json._

import scala.io.Source

/**
  * The `json` package contains implicit Reads/Writes/Formats instances to serialize and
  * deserialize basic TPC entities to and from Json format.
  **/
package object json {
  private def totalCountOk(c: Seq[Composition.Entry]): Boolean =
    (c map (_.count) fold 0) (_ + _) <= PLATFORM_NUM_SLOTS

  /* @{ TargetDesc */
  implicit val validatingTargetReads: Reads[TargetDesc] = (
    (JsPath \ "Architecture").read[String] ~
      (JsPath \ "Platform").read[String]
    ) (TargetDesc.apply _)

  implicit val targetWrites: Writes[TargetDesc] = (
    (JsPath \ "Architecture").write[String] ~
      (JsPath \ "Platform").write[String]
    ) (unlift(TargetDesc.unapply _))
  /* TargetDesc @} */

  /* @{ Architecture */
  def validatingArchitectureReads: Reads[Architecture] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "Name").read[String](minimumLength(length = 1)) ~
      (JsPath \ "TclLibrary").readNullable[Path].map(_ getOrElse Paths.get("test")) ~
      (JsPath \ "Description").readNullable[String].map(_ getOrElse "") ~
      (JsPath \ "ValueArgTemplate").readNullable[Path].map(_ getOrElse Paths.get("valuearg.directives.template")) ~
      (JsPath \ "ReferenceArgTemplate").readNullable[Path].map(_ getOrElse Paths.get("referencearg.directives.template")) ~
      (JsPath \ "AdditionalSteps").readNullable[Seq[String]].map(_ getOrElse Seq())
    ) (Architecture.apply _)

  implicit val architecturesWrites: Writes[Architecture] = (
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
        try {
          JsSuccess(LocalDateTime.parse(s, dtf))
        }
        catch {
          case e: Exception => JsError(Seq(JsPath() -> Seq(JsonValidationError(JsonErrors.ERROR_EXPECTED_DATE))))
        }
      }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError(JsonErrors.ERROR_EXPECTED_JSSTRING))))
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
    ) (Benchmark.apply _)
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
  implicit val validatingCompositionEntryReads: Reads[Composition.Entry] = (
    (JsPath \ "Kernel").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Count").read[Int](withinBounds(lowerBound = 1, upperBound = PLATFORM_NUM_SLOTS))
    ) (Composition.Entry.apply _)

  implicit val compositionEntryWrites: Writes[Composition.Entry] = (
    (JsPath \ "Kernel").write[String] ~
      (JsPath \ "Count").write[Int]
    ) (unlift(Composition.Entry.unapply _))
  /* Composition.Entry @} */

  /* @{ Composition */
  implicit val validatingCompositionReads: Reads[Composition] = (
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
  def validatingCoreReads(sourcePath: Path): Reads[Core] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "ZipFile").read[Path](pathExistsValidation(sourcePath)) ~
      (JsPath \ "Name").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Id").read[Kernel.Id](isValidKernelId) ~
      (JsPath \ "Version").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Target").read[TargetDesc] ~
      (JsPath \ "Description").readNullable[String] ~
      (JsPath \ "AverageClockCycles").readNullable[Long]
    ) (Core.apply _)
  implicit val coreWrites: Writes[Core] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
      (JsPath \ "ZipFile").write[Path] ~
      (JsPath \ "Name").write[String] ~
      (JsPath \ "Id").write[Int] ~
      (JsPath \ "Version").write[String] ~
      (JsPath \ "Target").write[TargetDesc] ~
      (JsPath \ "Description").writeNullable[String] ~
      (JsPath \ "AverageClockCycles").writeNullable[Long]
    ) (unlift(Core.unapply _))
  /* Core @} */

  /* @{ Features */
  implicit val readsFeature: Reads[Feature] = (
    (JsPath \ "Feature").read[String] ~
      (JsPath \ "Properties").read[Feature.FMap].orElse(readsFeatureFromFile)
    ) (Feature.apply _)

  lazy val readsFeatureFromFile: Reads[Feature.FMap] = new Reads[Feature.FMap] {
    def reads(json: JsValue): JsResult[Feature.FMap] = {
      val temp = (json \ "ConfigFile").validate[Path]

      temp.asEither match {
        case Right(s) => readMapFromFile(s)
        case Left(e) => new JsError(e)
      }
    }
  }

  // Read a Feature Config from an External Json File
  def readMapFromFile(p: Path): JsResult[Feature.FMap] = {
    val source = Source.fromFile(p.toString)
    val tmp = source.getLines.mkString
    source.close()
    Json.parse(tmp).validate[Feature.FMap]
  }

  implicit lazy val readsFeatureMap: Reads[Feature.FMap] = new Reads[Feature.FMap] {
    def reads(json: JsValue): JsResult[Feature.FMap] = {
      val temp = json.validate[Map[String, Feature.FValue]]
      val result: JsResult[Feature.FMap] = temp.asEither match {
        case Right(s) => new JsSuccess[Feature.FMap](Feature.FMap(s.toMap))
        case Left(e) => new JsError(e)
      }
      result
    }
  }

  implicit val readsFeatureList: Reads[Feature.FList] = new Reads[Feature.FList] {
    def reads(json: JsValue): JsResult[Feature.FList] = {
      val temp = json.validate[Seq[Feature.FValue]]

      val result: JsResult[Feature.FList] = temp.asEither match {
        case Right(s) => new JsSuccess[Feature.FList](Feature.FList(s.toList))
        case Left(e) => new JsError(e)
      }
      result
    }
  }

  // All non Object or Arrays are Strings for our Implementation
  implicit val readsFeatureString: Reads[Feature.FString] = new Reads[Feature.FString] {
    def reads(json: JsValue): JsResult[Feature.FString] = {
      val temp = json match {
        case s: JsString => s.validate[String]
        case i: JsNumber => i.validate[Double]
        case b: JsBoolean => b.validate[Boolean]
        case _ => new JsSuccess[String]("null")
      }

      val result = temp.asEither match {
        case Right(s) => new JsSuccess[Feature.FString](Feature.FString(s"${s}"))
        case Left(e) => new JsError(e)
      }

      result
    }
  }

  implicit val readsFeatureValue: Reads[Feature.FValue] = new Reads[Feature.FValue] {
    def reads(json: JsValue): JsResult[Feature.FValue] = {
      val temp: JsResult[Feature.FValue] = json match {
        case m: JsObject => m.validate[Feature.FMap]
        case l: JsArray => l.validate[Feature.FList]
        case x: JsValue => x.validate[Feature.FString]
      }
      temp
    }
  }


  implicit val writesFeature: Writes[Feature] = (
    (JsPath \ "Feature").write[String] ~
      (JsPath \ "Properties").write[Feature.FMap]
    ) (unlift(Feature.unapply _))
  //Converts the FMap to a JsonObject
  implicit lazy val writesFeatureMap: Writes[Feature.FMap] = new Writes[Feature.FMap] {
    def writes(myMap: Feature.FMap) = Json.parse(myMap.toJson)
  }

  /* Features @} */

  /* @{ Kernel.Argument */
  implicit object kernelPassingConventionFormat extends Format[Kernel.PassingConvention] {
    def reads(json: JsValue): JsResult[Kernel.PassingConvention] = json match {
      case JsString(str) =>
        if(List("by reference", "by value").contains(str)){
          JsSuccess(Kernel.PassingConvention(str))
        } else {
          JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.jsstring.for.passing.convention"))))
        }
      case _ => JsError(Seq(JsPath() -> Seq(JsonValidationError("expected.jsstring.for.passing.convention"))))
    }

    def writes(pc: Kernel.PassingConvention): JsValue = JsString(pc.toString)
  }

  implicit val kernelArgumentReads: Reads[Kernel.Argument] = (
    (JsPath \ "Name").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Passing").readNullable[Kernel.PassingConvention].map(_ getOrElse Kernel.PassingConvention.ByValue)
    ) (Kernel.Argument.apply _)
  implicit val kernelArgumentWrites: Writes[Kernel.Argument] = (
    (JsPath \ "Name").write[String] ~
      (JsPath \ "Passing").write[Kernel.PassingConvention]
    ) (unlift(Kernel.Argument.unapply _))
  /* Kernel.Argument @} */

  /* @{ Kernel */
  def validatingKernelReads(sourcePath: Path): Reads[Kernel] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "Name").read[String](minimumLength(length = 1))~
      (JsPath \ "TopFunction").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Id").read[Int](greaterZeroIntValidation) ~
      (JsPath \ "Version").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Files").read[Seq[Path]](pathsExistValidation(sourcePath)) ~
      (JsPath \ "TestbenchFiles").readNullable[Seq[Path]](pathsExistValidation(sourcePath)).map(_ getOrElse Seq()) ~
      (JsPath \ "Description").readNullable[String] ~
      (JsPath \ "CompilerFlags").readNullable[Seq[String]].map(_ getOrElse Seq()) ~
      (JsPath \ "TestbenchCompilerFlags").readNullable[Seq[String]].map(_ getOrElse Seq()) ~
      (JsPath \ "TestbenchArgv").readNullable[Seq[String]].map(_ getOrElse Seq()) ~
      (JsPath \ "Arguments").read[Seq[Kernel.Argument]] ~
      (JsPath \ "OtherDirectives").readNullable[Path](pathExistsValidation(sourcePath))
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
      (JsPath \ "TestbenchArgv").write[Seq[String]] ~
      (JsPath \ "Arguments").write[Seq[Kernel.Argument]] ~
      (JsPath \ "OtherDirectives").writeNullable[Path]
    ) (unlift(Kernel.unapply _))
  /* Kernel @} */

  /* @{ Platform */
  // scalastyle:off magic.number
  def validatingPlatformReads(sourcePath: Path): Reads[Platform] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "Name").read[String](minLength[String](1)) ~
      (JsPath \ "TclLibrary").read[Path] ~
      (JsPath \ "Part").read[String](minLength[String](1)) ~
      (JsPath \ "BoardPart").readNullable[String](minLength[String](4)) ~
      (JsPath \ "BoardPreset").readNullable[String](minLength[String](4)) ~
      (JsPath \ "BoardPartRepository").readNullable[String](minLength[String](4)) ~
      (JsPath \ "TargetUtilization").read[Int](min(5) keepAnd max(100)) ~
      (JsPath \ "SupportedFrequencies").readNullable[Seq[Int]](minLength[Seq[Int]](1)) ~
      (JsPath \ "MaximumFrequency").readNullable[Int].map(_.getOrElse(450)) ~
      (JsPath \ "SlotCount").readNullable[Int](min(1) keepAnd max(255)) ~
      (JsPath \ "Description").readNullable[String](minLength[String](1)) ~
      (JsPath \ "Benchmark").readNullable[Path] ~
      (JsPath \ "HostFrequency").readNullable[Double] ~
      (JsPath \ "MemFrequency").readNullable[Double] ~
      (JsPath \ "ImplementationTimeout").readNullable[Int] ~
      (JsPath \ "FileExtension").readNullable[String]
    ) (Platform.apply _)

  // scalastyle:on magic.number
  implicit def platformWrites: Writes[Platform] = (
    (JsPath \ "DescPath").write[Path].transform((js: JsObject) => js - "DescPath") ~
      (JsPath \ "Name").write[String] ~
      (JsPath \ "TclLibrary").write[Path] ~
      (JsPath \ "Part").write[String] ~
      (JsPath \ "BoardPart").writeNullable[String] ~
      (JsPath \ "BoardPreset").writeNullable[String] ~
      (JsPath \ "BoardPartRepository").writeNullable[String] ~
      (JsPath \ "TargetUtilization").write[Int] ~
      (JsPath \ "SupportedFrequencies").writeNullable[Seq[Int]] ~
      (JsPath \ "MaximumFrequency").write[Int] ~
      (JsPath \ "SlotCount").writeNullable[Int] ~
      (JsPath \ "Description").writeNullable[String] ~
      (JsPath \ "Benchmark").writeNullable[Path] ~
      (JsPath \ "HostFrequency").writeNullable[Double] ~
      (JsPath \ "MemFrequency").writeNullable[Double] ~
      (JsPath \ "ImplementationTimeout").writeNullable[Int] ~
      (JsPath \ "FileExtension").writeNullable[String]
    ) (unlift(Platform.unapply _))

  /* Platform @} */

  /* @{ Configuration */
  implicit val configurationReads: Reads[Configuration] = (
    (JsPath \ "DescPath").readNullable[Path].map(_ getOrElse Paths.get("N/A")) ~
      (JsPath \ "ArchDir").readNullable[Path].map(_ getOrElse BasePathManager.DEFAULT_DIR_ARCHS) ~
      (JsPath \ "PlatformDir").readNullable[Path].map(_ getOrElse BasePathManager.DEFAULT_DIR_PLATFORMS) ~
      (JsPath \ "KernelDir").readNullable[Path].map(_ getOrElse BasePathManager.DEFAULT_DIR_KERNELS) ~
      (JsPath \ "CoreDir").readNullable[Path].map(_ getOrElse BasePathManager.DEFAULT_DIR_CORES) ~
      (JsPath \ "CompositionDir").readNullable[Path].map(_ getOrElse BasePathManager.DEFAULT_DIR_COMPOSITIONS) ~
      (JsPath \ "LogFile").readNullable[Path] ~
      (JsPath \ "Slurm").readNullable[String] ~
      (JsPath \ "Parallel").readNullable[Boolean].map(_ getOrElse false) ~
      (JsPath \ "MaxThreads").readNullable[Int] ~
      (JsPath \ "MaxTasks").readNullable[Int] ~
      (JsPath \ "HlsTimeOut").readNullable[Int] ~
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
      (JsPath \ "Slurm").writeNullable[String] ~
      (JsPath \ "Parallel").write[Boolean] ~
      (JsPath \ "MaxThreads").writeNullable[Int] ~
      (JsPath \ "HlsTimeOut").writeNullable[Int] ~
      (JsPath \ "MaxTasks").writeNullable[Int] ~
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

  /* @{ SlurmRemoteConfig */
  implicit val slurmRemoteConfigReads: Reads[SlurmRemoteConfig] = (
      (JsPath \ "Name").read[String](minimumLength(length = 1)) ~
      (JsPath \ "SlurmHost").read[String](minimumLength(length = 1)) ~
      (JsPath \ "WorkstationHost").read[String](minimumLength(length = 1)) ~
      (JsPath \ "Workdir").read[Path] ~
      (JsPath \ "TapascoInstallDir").read[Path] ~
      (JsPath \ "JobFile").read[String](minimumLength(length = 1))
    ) (SlurmRemoteConfig.apply _)
  /* SlurmRemoteConfig @} */

}

// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
