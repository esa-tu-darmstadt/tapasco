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
package tapasco.task

import java.nio.file._

import tapasco.Logging._
import tapasco.activity.hls.HighLevelSynthesizer.Implementation
import tapasco.activity.hls._
import tapasco.base._
import tapasco.base.json._
import tapasco.filemgmt._
import tapasco.jobs.HighLevelSynthesisJob
import tapasco.slurm._
import tapasco.util._

class HighLevelSynthesisTask(val k: Kernel, val t: Target, val cfg: Configuration, hls: Implementation,
                             val onComplete: Boolean => Unit) extends Task with LogTracking {
  private[this] implicit val logger = tapasco.Logging.logger(getClass)
  private[this] var result: Option[HighLevelSynthesizer.Result] = None
  private[this] val slurm = Slurm.enabled
  private[this] val r = HighLevelSynthesizer(hls)
  private[this] val l = r.logFile(k, t)(cfg).resolveSibling("hls.log")

  def synthesizer: HighLevelSynthesizer = r

  def synthesisResult: Option[HighLevelSynthesizer.Result] = result

  def description: String =
    "High-Level-Synthesis for '%s' with target %s @ %s".format(k.name, t.pd.name, t.ad.name)

  def job: Boolean = if (!slurm) {
    val appender = LogFileTracker.setupLogFileAppender(l.toString)
    logger.trace("current thread name: {}", Thread.currentThread.getName())
    result = Some(r.synthesize(k, t)(cfg))
    LogFileTracker.stopLogFileAppender(appender)
    result map (_.toBoolean) getOrElse false
  } else {

    val cfgFile   = l.resolveSibling("slurm-hls.cfg") // Configuration Json
    val slurmLog  = l.resolveSibling("slurm-hls.log") // raw log file (stdout w/colors)
    val e         = l.resolveSibling("hls-slurm.errors.log")

    val hlsJob = HighLevelSynthesisJob(hls.toString, Some(Seq(t.ad.name)), Some(Seq(t.pd.name)), Some(Seq(k.name)))

    // define SLURM job
    val job = Slurm.Job(
      name = "hls-%s-%s-%s".format(t.ad.name, t.pd.name, k.name),
      log  = l,
      slurmLog = slurmLog,
      errorLog = e,
      consumer = this,
      maxHours = HighLevelSynthesisTask.MAX_SYNTH_HOURS,
      commands = Seq("tapasco --configFile %s".format(cfgFile.toString, k.name.toString)),
      job      = hlsJob,
      cfg_file = cfgFile
    )

    // execute sbatch to enqueue job, then wait for it
    val r = (Slurm(job)(cfg) map (Slurm.waitFor(_))).nonEmpty
    FileAssetManager.reset()
    r
  }

  def logFiles: Set[String] = Set(l.toString)

  // resource requirements
  val cpus = 1
  val memory = 4 * 1024 * 1024
  val licences = Map(
    "HLS" -> 1,
    "Synthesis" -> 1,
    "Implementation" -> 1,
    "Vivado_System_Edition" -> 1
  )
}

private object HighLevelSynthesisTask {
  final val MAX_SYNTH_HOURS = 8
}
