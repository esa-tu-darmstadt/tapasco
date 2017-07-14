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
 * @file    PrettyPrinter.scala
 * @brief   Implements pretty printing for Description subclasses.
 * @authors J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  scala.util.Properties.{lineSeparator => NL}

private object PrettyPrinter {
  def printArchitecture(a: Architecture): String = List(
      "[Architecture @" + a.descPath + "]",
      "Name = " + a.name,
      "TclLibrary = " + a.tclLibrary,
      "Description = " + a.description,
      "valueArgTemplate = " + a.valueArgTemplate,
      "referenceArgTemplate = " + a.referenceArgTemplate,
      "additionalSteps = " + a.additionalSteps.mkString(" ")
    ) mkString NL

  def printPlatform(p: Platform): String = List(
      "[Platform @" + p.descPath + "]",
      "Name = " + p.name,
      "Description = " + p.description,
      "TclLibrary = " + p.tclLibrary,
      "Part = " + p.part,
      "BoardPart = " + p.boardPart,
      "BoardPreset = " + p.boardPreset,
      "TargetUtilization = " + p.targetUtilization + "%",
      "SlotCount = " + p.slotCount,
      "HostFrequency = " + p.hostFrequency,
      "MemFrequency = " + p.memFrequency
    ) mkString NL

  def printKernelArg(ka: Kernel.Argument): String = ka.name + " " + ka.passingConvention

  def printKernel(k: Kernel): String = List(
      "[Kernel @" + k.descPath + "]",
      "Name = " + k.name,
      "TopFunction = " + k.topFunction,
      "Version = " + k.version,
      "Files = " + k.files.mkString(" "),
      "TestbenchFiles = " + k.testbenchFiles.mkString(" "),
      "CompilerFlags = " + k.compilerFlags.mkString(" "),
      "TestbenchCompilerFlags = " + k.testbenchCompilerFlags.mkString(" "),
      "Args = " + k.args.map(printKernelArg).mkString(" "),
      "OtherDirectives = " + k.otherDirectives
    ) mkString NL

  def printCompositionEntry(ce: Composition.Entry): String =
    List(ce.kernel, " x ", ce.count) mkString NL

  def printComposition(c: Composition): String = List(
      "[Composition @ " + c.id + "]",
      "Description = " + c.description,
      "Composition = " + (c.composition map { ce => ce.kernel + " x " + ce.count } mkString ", ")
    ) mkString NL

  def printConfiguration(c: Configuration): String = List(
      "[Configuration @" + c.descPath + "]",
      "Verbose = " + c.verbose,
      "KernelDir = " + c.kernelDir,
      "CoreDir = " + c.coreDir,
      "ArchDir = " + c.archDir,
      "PlatformDir = " + c.platformDir,
      "Slurm = " + c.slurm,
      "Parallel = " + c.parallel,
      "MaxThreads = " + (c.maxThreads getOrElse "unlimited"),
      "Jobs = " + c.jobs
    ) mkString NL

  def printCore(c: Core): String = List(
    "[Core @" + c.zipPath + "]",
    "Name = " + c.name,
    "ID = " + c.id,
    "Version = " + c.version,
    "Target = " + c.target,
    "Description = " + c.description,
    "Avg.CC = " + c.averageClockCycles
  ) mkString NL

  def printBenchmark(b: Benchmark): String = Seq(
    "[Benchmark @" + b.descPath.toString + "]",
    "Timestamp = " + b.timestamp.toString,
    "Host = " + b.host.toString,
    "LibVersions = " + b.libraryVersions.toString,
    "TransferSpeed = " + b.transferSpeed.toString,
    "IRQ latency = " + b.interruptLatency.toString
  ) mkString NL

  def print(d: Description): String = d match {
    case a: Architecture => printArchitecture(a)
    case p: Platform => printPlatform(p)
    case k: Kernel => printKernel(k)
    case c: Composition => printComposition(c)
    case c: Configuration => printConfiguration(c)
    case c: Core => printCore(c)
    case b: Benchmark => printBenchmark(b)
    case _ => "Unknown description"
  }
}
