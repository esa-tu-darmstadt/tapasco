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
 * @file    Common.scala
 * @brief   Common classes and tools for the GenerateX classes.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco
import  java.nio.file._
import  scala.sys.process._

/**
 * Contains the most basic common methods, e.g., to parse description files.
 **/
object Common {
  protected val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)

  lazy val homeDir: Path                      = Paths.get(sys.env("TAPASCO_HOME")).toAbsolutePath
  lazy val commonDir: Path                    = Paths.get(sys.env("TAPASCO_HOME")).resolve("common").toAbsolutePath
  //lazy val targetDesignFrequency: Option[Int] = sys.env.get("TAPASCO_FREQ") map (_.toInt)

  // FIXME implement software environment singleton for versions etc.

  def getVivadoVersion: String = try {
      Seq("vivado", "-version", "-nolog", "-nojournal").!!
    } catch { case ex: Exception =>
      throw new Exception("Could not find 'vivado' in path, please make sure you sourced the scripts.")
    }

  def checkEnvironment(needVivado: Boolean = false): Unit = {
    if (sys.env.get("TAPASCO_HOME").isEmpty) {
      throw new Exception("Environment variable 'TAPASCO_HOME' not set - please set to TPC base directory.")
    }
    if (needVivado) logger.info("Vivado version: " + getVivadoVersion)
  }

  def getFiles(dir: java.io.File): Array[java.io.File] =
    if (Option(dir).nonEmpty && dir.exists && Option(dir.listFiles).nonEmpty) {
      dir.listFiles ++ dir.listFiles.filter(_.isDirectory).flatMap(getFiles)
    } else {
      Array()
    }

  def getSubDirs(path: Path): Array[Path] =
    path.toFile.listFiles.filter(_.isDirectory) map (d => Paths.get(d.toString))
}
