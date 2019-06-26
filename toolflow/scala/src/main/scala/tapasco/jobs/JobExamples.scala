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

import java.io.FileWriter
import java.nio.file._

import play.api.libs.json._
import tapasco.Common
import tapasco.base._
import tapasco.dse._
import tapasco.jobs.json._

/** Contains an example for each kind of Tapasco job.
  * Can generate examples for their Json syntax.
  * via the dump method.
  */
object JobExamples {
  // scalastyle:off magic.number
  val bulkImportJob = BulkImportJob(Paths.get("some.csv"))
  val composition = Composition(Paths.get("N/A"),
    Some("An optional description."),
    Seq[Composition.Entry](Composition.Entry("counter", 42), Composition.Entry("k2", 42)))
  val composeJob = ComposeJob(composition,
    123.0,
    "Vivado",
    Some(Seq("axi4mm")),
    Some(Seq("pynq", "zedboard")),
    Some(Seq(Feature("LED", Feature.FMap(Map("enabled" -> Feature.FString("true")))))),
    Some("r"))
  val coreStatisticsJob = CoreStatisticsJob(Some("somePrefix_"),
    Some(Seq("axi4mm")),
    Some(Seq("vc709", "zc706")))
  val dseJob = DesignSpaceExplorationJob(composition,
    Some(123),
    DesignSpace.Dimensions(true, true, false),
    Heuristics.ThroughputHeuristic,
    Some(16),
    Some(Paths.get("nonstandard/base/path")),
    Some(Seq("axi4mm")),
    Some(Seq("pynq", "vc709")),
    Some(Seq(Feature("LED", Feature.FMap(Map("enabled" -> Feature.FString("true")))))),
    Some("r"))
  val hlsJob = HighLevelSynthesisJob("VivadoHLS",
    Some(Seq("axi4mm")),
    Some(Seq("zedboard", "zc706")),
    Some(Seq("counter", "arraysum")))
  val importJob = ImportJob(Paths.get("path/to/ipxact-archive.zip"),
    42,
    Some("Optional description of the core."),
    Some(13124425),
    Some(true),
    Some("-retiming"),
    Some(Seq("axi4mm")),
    Some(Seq("zedboard", "zc706")),
    Some(3))

  val jobs: Seq[Job] = Seq(bulkImportJob, composeJob, coreStatisticsJob, dseJob, hlsJob, importJob)

  /** Dumps examples into separate files in json-examples/jobs. */
  def dump {
    val fn = Common.homeDir.resolve("json-examples").resolve("jobs").resolve("Jobs.json")
    Files.createDirectories(fn.getParent)
    val fw = new FileWriter(fn.toString)
    fw.append(Json.prettyPrint(Json.toJson(jobs)))
    fw.close()
    jobs foreach { j =>
      val jfn = fn.resolveSibling("%s.json".format(j.getClass.getSimpleName))
      val fw = new FileWriter(jfn.toString)
      fw.append(Json.prettyPrint(Json.toJson(j)))
      fw.close()
    }
  }

  // scalastyle:on magic.number
}
