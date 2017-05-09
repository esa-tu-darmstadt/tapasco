//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file    Configuration.scala
 * @brief   Model: TPC Configuration.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.threadpoolcomposer.base
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs._
import  java.nio.file._
import  builder._

trait Configuration {
  def descPath: Path
  def descPath(p: Path): Configuration
  def archDir: Path
  def archDir(p: Path): Configuration
  def platformDir: Path
  def platformDir(p: Path): Configuration
  def kernelDir: Path
  def kernelDir(p: Path): Configuration
  def coreDir: Path
  def coreDir(p: Path): Configuration
  def compositionDir: Path
  def compositionDir(p: Path): Configuration
  def jobs: Seq[Job]
  def jobs(js: Seq[Job]): Configuration
  def logFile: Option[Path]
  def logFile(p: Option[Path]): Configuration
  def slurm: Boolean
  def slurm(enabled: Boolean): Configuration

  def outputDir(kernel: Kernel, target: Target): Path =
    coreDir.resolve(kernel.name.toString).resolve(target.ad.name).resolve(target.pd.name)
  def outputDir(composition: Composition, target: Target, freq: Double): Path =
    compositionDir.resolve(composition.id + "--" + ("%2.3f" format freq))
        .resolve(target.ad.name).resolve(target.pd.name)
  def outputDir(core: Core, target: Target): Path =
    coreDir.resolve(core.name.toString).resolve(target.ad.name).resolve(target.pd.name)
  def outputDir(name: String, target: Target): Path =
    coreDir.resolve(name).resolve(target.ad.name).resolve(target.pd.name)
}

object Configuration extends Builds[Configuration] {
  /** Return default implementation for [[Configuration]]. */
  def apply(): Configuration = ConfigurationImpl()
}
