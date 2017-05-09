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
 * @file     BenchmarkTest.scala
 * @brief    Unit tests for Benchmark description file.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.base
import  json._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  java.nio.file._
import  java.time.{LocalDate, LocalDateTime}

class BenchmarkSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  val jsonPath = Paths.get("json-examples").toAbsolutePath

  "All library versions" should "be read and written correctly" in {
    import play.api.libs.json._

    check(forAll { lv: LibraryVersions =>
      val json = Json.prettyPrint(Json.toJson(lv))
      val plv = Json.fromJson[LibraryVersions](Json.parse(json))
      plv.get.equals(lv)
    })
  }

  "All host definitions" should "be read and written correctly" in {
    import play.api.libs.json._

    check(forAll { host: Host =>
      val json = Json.prettyPrint(Json.toJson(host))
      val phost = Json.fromJson[Host](Json.parse(json))
      phost.get.equals(host)
    })
  }

  "All transfer speed measurements" should "be read and written correctly" in {
    import play.api.libs.json._

    check(forAll { tsm: TransferSpeedMeasurement =>
      val json = Json.prettyPrint(Json.toJson(tsm))
      val ptsm = Json.fromJson[TransferSpeedMeasurement](Json.parse(json))
      ptsm.get.equals(tsm)
    })
  }

  "All valid benchmarks" should "be read and written correctly" in {
    import play.api.libs.json._

    check(forAllNoShrink { b: Benchmark =>
      val pb = Benchmark.from((Benchmark.to(b)))
      if (pb.isLeft) {
        System.out.println("invalid benchmark: " + Json.prettyPrint(Benchmark.to(b)))
      } else if (! pb.right.get.equals(b)) {
        val b2 = pb.right.get
        if (! b2.timestamp.equals(b.timestamp)) {
          val dtf = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-d kk:mm:ss")
          System.out.println("%s != %s".format(b2.timestamp.toString, b.timestamp.toString))
          System.out.println("%s != %s".format(b2.timestamp.format(dtf), b.timestamp.format(dtf)))
        }
      }
      pb.isRight && pb.right.get.equals(b)
    })
  }

  "A missing Benchmark file" should "not throw an exception" in {
    assert(Benchmark.from(jsonPath.resolve("missing.json")).isLeft)
  }

  "A correct Benchmark file" should "be parsed to Some(Benchmark)" in {
    assert(Benchmark.from(jsonPath.resolve("correct-benchmark.json")).isRight)
  }
  
  "A correct Benchmark file" should "be parsed correctly" in {
    val oc = Benchmark.from(jsonPath.resolve("correct-benchmark.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    // host data
    c.host.machine should be ("x86_64")
    c.host.node should equal ("mountdoom")
    c.host.operatingSystem should equal ("Linux")
    c.host.release should equal ("3.19.8-100.fc20.x86_64")
    c.host.version should equal ("#1 SMP Tue May 12 17:08:50 UTC 2015")
    // interrupt latency
    c.interruptLatency should equal (90.900809919008182)
    // library versions
    c.libraryVersions.platform should equal ("1.2.1")
    c.libraryVersions.tapasco should equal ("1.2")
    // timestamp
    c.timestamp should equal (LocalDate.of(2016, 4, 20).atTime(16,33,49))
    // transfer speed
    c.transferSpeed should have length (18)
    var ce = c.transferSpeed(17)
    ce.chunkSize should equal (33554432)
    ce.read should equal (3322.1144740468026)
    ce.write should equal (3178.9272608933888)
    ce.readWrite should equal (3182.0719464635727)
    ce = c.transferSpeed(0)
    ce.chunkSize should equal (256)
    ce.read should equal (49.329030801393962)
    ce.write should equal (48.829431984156649)
    ce.readWrite should equal (55.568662824206989)
  }
  
  "A Benchmark file with unknown entries" should "be parsed correctly" in {
    val oc = Benchmark.from(jsonPath.resolve("correct-benchmark.json"))
    lazy val c = oc.right.get
    assert(oc.isRight)
    // host data
    c.host.machine should equal ("x86_64")
    c.host.node should equal ("mountdoom")
    c.host.operatingSystem should equal ("Linux")
    c.host.release should equal ("3.19.8-100.fc20.x86_64")
    c.host.version should equal ("#1 SMP Tue May 12 17:08:50 UTC 2015")
    // interrupt latency
    c.interruptLatency should equal (90.900809919008182)
    // library versions
    c.libraryVersions.platform should equal ("1.2.1")
    c.libraryVersions.tapasco should equal ("1.2")
    // timestamp
    c.timestamp should equal (LocalDate.of(2016, 4, 20).atTime(16,33,49))
    // transfer speed
    c.transferSpeed should have length (18)
    var ce = c.transferSpeed(17)
    ce.chunkSize should equal (33554432)
    ce.read should equal (3322.1144740468026)
    ce.write should equal (3178.9272608933888)
    ce.readWrite should equal (3182.0719464635727)
    ce = c.transferSpeed(0)
    ce.chunkSize should equal (256)
    ce.read should equal (49.329030801393962)
    ce.write should equal (48.829431984156649)
    ce.readWrite should equal (55.568662824206989)
  }

  "An invalid Benchmark file" should "not be parsed" in {
    val oc1 = Benchmark.from(jsonPath.resolve("invalid-benchmark.json"))
    assert(oc1.isLeft)
  }

  /* @{ Generators and Arbitraries */
  import org.scalacheck._
  val lvGen: Gen[LibraryVersions] = for {
    v1 <- Arbitrary.arbitrary[String]
    v2 <- Arbitrary.arbitrary[String]
  } yield LibraryVersions(v1, v2)
  implicit val arbLv: Arbitrary[LibraryVersions] = Arbitrary(lvGen)

  val posIntsPowerTwo: Gen[Int] = Gen.posNum[Int] map (n => 1 << n)
  val tsmGen: Gen[TransferSpeedMeasurement] = for {
    cs <- posIntsPowerTwo
    r  <- Gen.posNum[Double]
    w  <- Gen.posNum[Double]
    rw <- Gen.posNum[Double]
  } yield TransferSpeedMeasurement(cs, r, w, rw)
  implicit val arbTsm: Arbitrary[TransferSpeedMeasurement] = Arbitrary(tsmGen)

  val hostGen = for {
    machine <- Arbitrary.arbitrary[String]
    node <- Arbitrary.arbitrary[String]
    os <- Arbitrary.arbitrary[String]
    release <- Arbitrary.arbitrary[String]
    version <- Arbitrary.arbitrary[String]
  } yield Host(machine, node, os, release, version)
  implicit val arbHost: Arbitrary[Host] = Arbitrary(hostGen)

  val localDateTimeGen = for {
    year  <- Gen.choose(1970, 3500)
    month <- Gen.choose(1, 12)
    day   <- Gen.choose(1, 29)
    hour  <- Gen.choose(0, 23)
    min   <- Gen.choose(0, 59)
    sec   <- Gen.choose(0, 59)
  } yield LocalDateTime.parse("%04d-%02d-%02dT%02d:%02d:%02d".format(year, month, day, hour, min, sec))
  implicit val arbLocalDateTime: Arbitrary[LocalDateTime] = Arbitrary(localDateTimeGen)

  val benchmarkGen = for {
    timestamp <- Arbitrary.arbitrary[LocalDateTime]
    host <- Arbitrary.arbitrary[Host]
    lv <- Arbitrary.arbitrary[LibraryVersions]
    tsm <- Arbitrary.arbitrary[Seq[TransferSpeedMeasurement]]
    il <- Gen.posNum[Double]
  } yield Benchmark(java.nio.file.Paths.get("N/A"), timestamp, host, lv, tsm, il)
  implicit val arbBenchmark: Arbitrary[Benchmark] = Arbitrary(benchmarkGen)

  /* Generators and Arbitraries @} */
}
// vim: foldmethod=marker foldmarker=@{,@} foldlevel=0
