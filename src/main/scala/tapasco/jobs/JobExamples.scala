package de.tu_darmstadt.cs.esa.tapasco.jobs
import  de.tu_darmstadt.cs.esa.tapasco.Common
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  json._
import  play.api.libs.json._
import  java.io.FileWriter
import  java.nio.file._

/** Contains an example for each kind of Tapasco job.
 *  Can generate examples for their Json syntax in $TAPASCO_HOME/json-examples/jobs
 *  via the [[dump]] method.
 */
object JobExamples {
  val bulkImportJob = BulkImportJob(Paths.get("some.csv"))
  val composition = Composition(Paths.get("N/A"),
                                Some("An optional description."),
                                Seq[Composition.Entry](Composition.Entry("counter", 42), Composition.Entry("k2", 42)))
  val composeJob = ComposeJob(composition,
                              123.0,
                              "Vivado",
                              Some(Seq("axi4mm")),
                              Some(Seq("pynq", "zedboard")),
                              None, // FIXME Features missing
                              Some("r"))
  val coreStatisticsJob = CoreStatisticsJob(Some("somePrefix_"),
                                            Some(Seq("axi4mm")),
                                            Some(Seq("vc709", "zc706")))
  val dseJob = DesignSpaceExplorationJob(composition,
                                         123.0,
                                         DesignSpace.Dimensions(true, true, false),
                                         Heuristics.ThroughputHeuristic,
                                         16,
                                         Some(Paths.get("nonstandard/base/path")),
                                         Some(Seq("axi4mm")),
                                         Some(Seq("pynq", "vc709")),
                                         None, // FIXME Features missing
                                         Some("r"))
  val hlsJob = HighLevelSynthesisJob("VivadoHLS",
                                     Some(Seq("axi4mm")),
                                     Some(Seq("zedboard", "zc706")),
                                     Some(Seq("counter", "arraysum")))
  val importJob = ImportJob(Paths.get("path/to/ipxact-archive.zip"),
                            42,
                            Some("Optional description of the core."),
                            Some(13124425),
                            Some(Seq("axi4mm")),
                            Some(Seq("zedboard", "zc706")))

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
}
