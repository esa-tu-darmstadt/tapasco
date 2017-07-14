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
 * @file     ConfigurationTest.scala
 * @brief    Unit tests for Configuration description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  de.tu_darmstadt.cs.esa.tapasco.jobs._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  de.tu_darmstadt.cs.esa.tapasco.parser.CommandLineParser
import  org.scalatest._
import  java.nio.file._
import  json._

class ConfigurationSpec extends FlatSpec with Matchers {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "A missing Configuration file" should "throw an exception" in {
    assert(Configuration.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Configuration file" should "be parsed to Some(Configuration)" in {
    val v = Configuration.from(jsonPath.resolve("configTest/config.json"))
    if (v.isLeft) { logger.error("{}, stacktrace: {}", v.left.get: Any, v.left.get.getStackTrace() mkString "\n") }
    assert(v.isRight) 
  }

  "A correct Configuration file" should "be parsed correctly" in {
    val oc = Configuration.from(jsonPath.resolve("configTest/config.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    FileAssetManager(c)
    Thread.sleep(50)
    logger.trace("architectures: {}", FileAssetManager.entities.architectures map (_.name))
    logger.trace("platforms: {}", FileAssetManager.entities.platforms map (_.name))
    logger.trace("kernels: {}", FileAssetManager.entities.kernels map (_.name))
    assert(c.jobs.length == 3)
    val j1 = c.jobs(0)
    val j2 = c.jobs(1)
    val j3 = c.jobs(2)
    j1 match {
      case hj: HighLevelSynthesisJob =>
        hj.architectures.map(_.name).toSet should contain only ("Arch1", "Arch3")
        hj.platforms.map(_.name).toSet should contain only ("Plat1", "Plat2")
        hj.kernels.map(_.name).toSet should contain only ("Kern2", "Kern3")
      case _ => assert(false, "expected HighLevelSynthesisJob at index 0 in jobs array")
    }
    j2 match {
      case cj: ComposeJob =>
        cj.architectures.map(_.name).toSet should contain only ("Arch1", "Arch3")
        cj.platforms.map(_.name).toSet should contain only ("Plat1", "Plat2")
        cj.composition.composition.head.count should be (42)
      case _ => assert(false, "expected ComposeJob at index 1 in jobs array")
    }
    j3 match {
      case cj: ComposeJob =>
        cj.architectures.map(_.name).toSet should contain only ("Arch3")
        cj.platforms.map(_.name).toSet should contain only ("Plat2")
        cj.composition.description should be (Some("Inline Composition"))
        cj.composition.composition.head.kernel should be ("Kern1")
      case _ => assert(false, "expected ComposeJob at index 2 in jobs array")
    }
  }

  "An invalid Configuration file" should "not be parsed" in {
    assert(Configuration.from(jsonPath.resolve("invalid-config.json")).isLeft)
  }

  "A Configuration file" should "be overriden by direct args" in {
    val oc = CommandLineParser(Seq(
      "--configFile", jsonPath.resolve("configTest/config.json").toString,
      "--archDir", "kernel",
      "--platformDir", "arch",
      "--kernelDir", "platform") mkString " ")
    lazy val c = oc.right.get
    oc.swap foreach { throw _ }
    assert(oc.isRight)
    c.archDir should be (jsonPath.resolve("configTest/kernel"))
    c.platformDir should be (jsonPath.resolve("configTest/arch"))
    c.kernelDir should be (jsonPath.resolve("configTest/platform"))
  }

  "Jobs in Configuration file" should "be appended by direct args" in {
    val oc = CommandLineParser(Seq(
      "--configFile", jsonPath.resolve("configTest/config.json").toString,
      "corestats", "-a", "Arch1") mkString " ")
    lazy val c = oc.right.get
    oc.swap foreach { throw _ }
    assert(oc.isRight)
    c.jobs.size should be (4)
    c.jobs(3) match {
      case j: CoreStatisticsJob =>
        j.architectures map (_.name) should contain only ("Arch1")
      case j => { println(j); assert(false, "expected CoreStatisticsJob at in index 1 in jobs array") }
    }
  }

  "Jobs in Configuration file" should "be overidden by jobs file" in {
    val oc = CommandLineParser(Seq(
      "--configFile", jsonPath.resolve("configTest/config.json").toString,
      "--jobsFile", jsonPath.resolve("configTest").resolve("jobs.json")) mkString " ")
    lazy val c = oc.right.get
    oc.swap foreach { e => println(e); throw e }
    assert(oc.isRight)
    c.jobs.size should be (6)
  }
}
