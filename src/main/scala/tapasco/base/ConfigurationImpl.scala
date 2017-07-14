//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
/**
 * @file    ConfigurationImpl.scala
 * @brief   Model: TPC Configuration.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.{Common => TapascoCommon}
import  de.tu_darmstadt.cs.esa.tapasco.json._
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  java.nio.file._

/**
 * Internal implementation of [[Configuration]]:
 * Configuration requires a lot of massaging and post-processing of the
 * arguments, e.g., all kinds of entities must be read from the given
 * file names etc.
 **/
private case class ConfigurationImpl (
      descPath: Path                                  = TapascoCommon.homeDir.resolve("default.cfg"),
      private val _archDir: Path                      = TapascoCommon.homeDir.resolve("arch"),
      private val _platformDir: Path                  = TapascoCommon.homeDir.resolve("platform"),
      private val _kernelDir: Path                    = TapascoCommon.homeDir.resolve("kernel"),
      private val _coreDir: Path                      = TapascoCommon.homeDir.resolve("core"),
      private val _compositionDir: Path               = TapascoCommon.homeDir.resolve("bd"),
      private val _logFile: Option[Path]              = None,
      slurm: Boolean                                  = false,
      parallel: Boolean                               = false,
      maxThreads: Option[Int]                         = None,
      dryRun: Option[Path]                            = None,
      verbose: Option[String]                         = None,
      jobs: Seq[Job]                                  = Seq()
    ) extends Description(descPath: Path) with Configuration {
  def descPath(p: Path): Configuration                = this.copy(descPath = p)
  val archDir: Path                                   = resolve(_archDir)
  def archDir(p: Path): Configuration                 = this.copy(_archDir = p)
  val compositionDir: Path                            = resolve(_compositionDir)
  def compositionDir(p: Path): Configuration          = this.copy(_compositionDir = p)
  val coreDir: Path                                   = resolve(_coreDir)
  def coreDir(p: Path): Configuration                 = this.copy(_coreDir = p)
  val kernelDir: Path                                 = resolve(_kernelDir)
  def kernelDir(p: Path): Configuration               = this.copy(_kernelDir = p)
  val platformDir: Path                               = resolve(_platformDir)
  def platformDir(p: Path): Configuration             = this.copy(_platformDir = p)
  val logFile: Option[Path]                           = _logFile map (resolve _)
  def logFile(op: Option[Path]): Configuration        = this.copy(_logFile = op)
  def slurm(enabled: Boolean): Configuration          = this.copy(slurm = enabled)
  def parallel(enabled: Boolean): Configuration       = this.copy(parallel = enabled)
  def maxThreads(mt: Option[Int]): Configuration      = this.copy(maxThreads = mt)
  def dryRun(cfg: Option[Path]): Configuration        = this.copy(dryRun = cfg)
  def verbose(mode: Option[String]): Configuration    = this.copy(verbose = mode)
  def jobs(js: Seq[Job]): Configuration               = this.copy(jobs = js)

  // these directories must exist
  for ((d, n) <- Seq((archDir, "architectures"),
                     (kernelDir, "kernels"),
                     (platformDir, "platforms")))
    require(mustExist(d), "%s directory %s does not exist".format(n, d.toString))
}
