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
/**
  * @file ConfigurationImpl.scala
  * @brief Model: TPC Configuration.
  * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
  **/
package tapasco.base

import java.nio.file._

import tapasco.filemgmt.BasePathManager
import tapasco.jobs._
import tapasco.json._

/**
  * Internal implementation of [[Configuration]]:
  * Configuration requires a lot of massaging and post-processing of the
  * arguments, e.g., all kinds of entities must be read from the given
  * file names etc.
  **/
private case class ConfigurationImpl(
                                      descPath: Path = Paths.get(System.getProperty("user.dir")).resolve("default.cfg"),
                                      private val _archDir: Path = BasePathManager.DEFAULT_DIR_ARCHS,
                                      private val _platformDir: Path = BasePathManager.DEFAULT_DIR_PLATFORMS,
                                      private val _kernelDir: Path = BasePathManager.DEFAULT_DIR_KERNELS,
                                      private val _coreDir: Path = BasePathManager.DEFAULT_DIR_CORES,
                                      private val _compositionDir: Path = BasePathManager.DEFAULT_DIR_COMPOSITIONS,
                                      private val _logFile: Option[Path] = None,
                                      slurm: Option[String] = None,
                                      parallel: Boolean = false,
                                      maxThreads: Option[Int] = None,
                                      maxTasks: Option[Int] = None,
                                      hlsTimeOut: Option[Int] = None,
                                      dryRun: Option[Path] = None,
                                      verbose: Option[String] = None,
                                      jobs: Seq[Job] = Seq()
                                    ) extends Description(descPath) with Configuration {
  def descPath(p: Path): Configuration = this.copy(descPath = p)

  val archDir: Path = resolve(_archDir)

  def archDir(p: Path): Configuration = this.copy(_archDir = p)

  val compositionDir: Path = resolve(_compositionDir)

  def compositionDir(p: Path): Configuration = this.copy(_compositionDir = p)

  val coreDir: Path = resolve(_coreDir)

  def coreDir(p: Path): Configuration = this.copy(_coreDir = p)

  val kernelDir: Path = resolve(_kernelDir)

  def kernelDir(p: Path): Configuration = this.copy(_kernelDir = p)

  val platformDir: Path = resolve(_platformDir)

  def platformDir(p: Path): Configuration = this.copy(_platformDir = p)

  val logFile: Option[Path] = _logFile map (resolve _)

  def logFile(op: Option[Path]): Configuration = this.copy(_logFile = op)

  def slurm(template: Option[String]): Configuration = this.copy(slurm = template)

  def parallel(enabled: Boolean): Configuration = this.copy(parallel = enabled)

  def maxThreads(mt: Option[Int]): Configuration = this.copy(maxThreads = mt)

  def hlsTimeOut(timeout: Option[Int]): Configuration = this.copy(hlsTimeOut = timeout)

  def maxTasks(mt: Option[Int]): Configuration = this.copy(maxTasks = mt)

  def dryRun(cfg: Option[Path]): Configuration = this.copy(dryRun = cfg)

  def verbose(mode: Option[String]): Configuration = this.copy(verbose = mode)

  def jobs(js: Seq[Job]): Configuration = this.copy(jobs = js)

  // these directories must exist, unless we execute on remote SLURM node
  if (this.slurm.getOrElse(true).equals("local")) {
    for ((d, n) <- Seq((archDir, "architectures"),
      (platformDir, "platforms")))
      require(mustExist(d), "%s directory %s does not exist".format(n, d.toString))
  }
}
