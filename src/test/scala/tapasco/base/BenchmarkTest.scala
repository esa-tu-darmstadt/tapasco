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
import  org.scalacheck._
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

  "All interrupt latency measurements" should "be read and written correctly" in {
    import play.api.libs.json._

    check(forAll { ilm: InterruptLatency =>
      val json = Json.prettyPrint(Json.toJson(ilm))
      val ptsm = Json.fromJson[InterruptLatency](Json.parse(json))
      ptsm.get.equals(ilm)
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
    c.host.machine should be ("armv7l")
    c.host.node should equal ("pynq")
    c.host.operatingSystem should equal ("Linux")
    c.host.release should equal ("4.6.0-tapasco")
    c.host.version should equal ("#1 SMP PREEMPT Fri May 26 16:26:16 CEST 2017")
    // job throughput
    c.jobThroughput should have length (8)
    c.jobThroughput should equal (List(
        JobThroughput(1, 119074.73866666667),
        JobThroughput(2, 246078.71600000001),
        JobThroughput(3, 237654.358),
        JobThroughput(4, 231967.13166666668),
        JobThroughput(5, 226561.87117590103),
        JobThroughput(6, 222900.86777777775),
        JobThroughput(7, 218548.3080264527),
        JobThroughput(8, 215949.0373333333)))
    // interrupt latency
    c.interruptLatency should have length (3)
    c.interruptLatency should equal (List(
        InterruptLatency(1, 10.01592947927347, 9, 156),
        InterruptLatency(2, 164.85714285714286, 162, 171),
        InterruptLatency(2147483648L, 276.69565217391295, 269, 282)))
    // library versions
    c.libraryVersions.platform should equal ("1.2.1")
    c.libraryVersions.tapasco should equal ("1.2")
    // timestamp
    c.timestamp should equal (LocalDate.of(2017, 5, 30).atTime(13,8,55))
    // transfer speed
    c.transferSpeed should have length (3)
    var ce = c.transferSpeed(1)
    ce.chunkSize should equal (2048)
    ce.read should equal (36.913918454834466)
    ce.write should equal (42.449135015215866)
    ce.readWrite should equal (69.51085992539018)
    ce = c.transferSpeed(0)
    ce.chunkSize should equal (1024)
    ce.read should equal (20.078207396701792)
    ce.write should equal (21.68177044056579)
    ce.readWrite should equal (37.784625316971535)
  }

  "An invalid Benchmark file" should "not be parsed" in {
    val oc1 = Benchmark.from(jsonPath.resolve("invalid-benchmark.json"))
    assert(oc1.isLeft)
  }

  "Transfer speeds" should "be correcty interpolated between two values" in {
    check(forAll { (bm: Benchmark, a: TransferSpeedMeasurement, b: TransferSpeedMeasurement) =>
        (a.chunkSize != b.chunkSize) ==> {
      val data = Seq(a, b).sortBy(_.chunkSize)
      val l = if (a.chunkSize < b.chunkSize) a else b
      val r = if (a.chunkSize < b.chunkSize) b else a
      val mbm = bm.copy(transferSpeed = data)
      val cs = Gen.choose(0, r.chunkSize + 1)
      def interpolate(cs: Long, lcs: Long, ls: Double, rcs: Long, rs: Double): Double =
         (((cs - lcs).toDouble / (rcs - lcs).toDouble)) * (rs  - ls) + ls
      forAll(cs) { n => n match {
        case n if n <= l.chunkSize => mbm.speed(n) equals (l.read, l.write, l.readWrite)
        case n if n >= r.chunkSize => mbm.speed(n) equals (r.read, r.write, r.readWrite)
        case n => mbm.speed(n) equals ((interpolate(n, l.chunkSize, l.read, r.chunkSize, r.read),
                                        interpolate(n, l.chunkSize, l.write, r.chunkSize, r.write),
                                        interpolate(n, l.chunkSize, l.readWrite, r.chunkSize, r.readWrite)))
      }}
    }})
  }

  "Transfer speeds" should "be correcty interpolated between three values" in {
    check(forAll { (bm: Benchmark, a: TransferSpeedMeasurement, b: TransferSpeedMeasurement,
        c: TransferSpeedMeasurement) => (a.chunkSize != b.chunkSize && b.chunkSize != c.chunkSize &&
            a.chunkSize != c.chunkSize)  ==> {
      val data = Seq(a, b, c).sortBy(_.chunkSize)
      val bot = data.head
      val mid = data.tail.head
      val top = data.last
      val mbm = bm.copy(transferSpeed = data)
      val cs = Gen.choose(0, top.chunkSize + 1)
      def interpolate(cs: Long, lcs: Long, ls: Double, rcs: Long, rs: Double): Double =
         (((cs - lcs).toDouble / (rcs - lcs).toDouble)) * (rs  - ls) + ls
      forAll(cs) { n => {
        val l = if (n <= mid.chunkSize) bot else mid
        val r = if (n <= mid.chunkSize) mid else top
        n match {
          case n if n <= l.chunkSize => mbm.speed(n) equals (l.read, l.write, l.readWrite)
          case n if n >= r.chunkSize => mbm.speed(n) equals (r.read, r.write, r.readWrite)
          case n => mbm.speed(n) equals (interpolate(n, l.chunkSize, l.read, r.chunkSize, r.read),
                                         interpolate(n, l.chunkSize, l.write, r.chunkSize, r.write),
                                         interpolate(n, l.chunkSize, l.readWrite, r.chunkSize, r.readWrite))
      }}}}
    })
  }

  "Interrupt latency" should "be correcty interpolated between two values" in {
    check(forAll { (bm: Benchmark, a: InterruptLatency, b: InterruptLatency) =>
        (a.clockCycles != b.clockCycles) ==> {
      val data = Seq(a, b).sortBy(_.clockCycles)
      val l = if (a.clockCycles < b .clockCycles) a else b
      val r = if (a.clockCycles < b .clockCycles) b else a
      val mbm = bm.copy(interruptLatency = data)
      val cc = Gen.choose(0, b.clockCycles + 1)
      forAll(cc) { n => n match {
        case n if n <= l.clockCycles => mbm.latency(n) equals l.latency 
        case n if n >= r.clockCycles => mbm.latency(n) equals r.latency
        case n => mbm.latency(n) equals
         (((n - l.clockCycles).toDouble / (r.clockCycles - l.clockCycles).toDouble)) *
         (r.latency  - l.latency) + l.latency
      }}
    }})
  }

  "Interrupt latency" should "be correcty interpolated between three values" in {
    check(forAll { (bm: Benchmark, a: InterruptLatency, b: InterruptLatency, c: InterruptLatency) =>
        (a.clockCycles != b.clockCycles && b.clockCycles != c.clockCycles && a.clockCycles != c.clockCycles) ==> {
      val data = Seq(a, b).sortBy(_.clockCycles)
      val bot = data.head
      val mid = data.tail.head
      val top = data.last
      val mbm = bm.copy(interruptLatency = data)
      val cc = Gen.choose(0, b.clockCycles + 1)
      forAll(cc) { n => {
        val l = if (n <= mid.clockCycles) bot else mid
        val r = if (n <= mid.clockCycles) mid else top
        n match {
          case n if n <= l.clockCycles => mbm.latency(n) equals l.latency 
          case n if n >= r.clockCycles => mbm.latency(n) equals r.latency
          case n => mbm.latency(n) equals
           (((n - l.clockCycles).toDouble / (r.clockCycles - l.clockCycles).toDouble)) *
           (r.latency  - l.latency) + l.latency
      }}}
    }})
  }

  /* @{ Generators and Arbitraries */
  import org.scalacheck._
  val lvGen: Gen[LibraryVersions] = for {
    v1 <- Arbitrary.arbitrary[String]
    v2 <- Arbitrary.arbitrary[String]
  } yield LibraryVersions(v1, v2)
  implicit val arbLv: Arbitrary[LibraryVersions] = Arbitrary(lvGen)

  val posIntsPowerTwo: Gen[Int] = Gen.posNum[Int] map (n => 1 << (n % 31))
  val tsmGen: Gen[TransferSpeedMeasurement] = for {
    cs <- posIntsPowerTwo
    r  <- Gen.posNum[Double]
    w  <- Gen.posNum[Double]
    rw <- Gen.posNum[Double]
  } yield TransferSpeedMeasurement(cs, r, w, rw)
  implicit val arbTsm: Arbitrary[TransferSpeedMeasurement] = Arbitrary(tsmGen)

  val ilmGen: Gen[InterruptLatency] = for {
    cl <- posIntsPowerTwo
    v1  <- Gen.posNum[Double]
    v2  <- Gen.posNum[Double]
    v3  <- Gen.posNum[Double]
    vs = Seq(v1, v2, v3).sorted
  } yield InterruptLatency(cl, vs(1), vs(0), vs(1))
  implicit val arbIlm: Arbitrary[InterruptLatency] = Arbitrary(ilmGen)

  val jtGen: Gen[JobThroughput] = for {
    t <- Gen.posNum[Int]
    j <- Gen.posNum[Double]
  } yield JobThroughput(t, j)
  implicit val arbJt: Arbitrary[JobThroughput] = Arbitrary(jtGen)

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
    day   <- Gen.choose(1, 28)
    hour  <- Gen.choose(0, 23)
    min   <- Gen.choose(0, 59)
    sec   <- Gen.choose(0, 59)
  } yield LocalDateTime.parse("%04d-%02d-%02dT%02d:%02d:%02d".format(year, month, day, hour, min, sec))
  implicit val arbLocalDateTime: Arbitrary[LocalDateTime] = Arbitrary(localDateTimeGen)

  val benchmarkGen = for {
    timestamp <- Arbitrary.arbitrary[LocalDateTime]
    host      <- Arbitrary.arbitrary[Host]
    lv        <- Arbitrary.arbitrary[LibraryVersions]
    tsm       <- Arbitrary.arbitrary[Seq[TransferSpeedMeasurement]]
    il        <- Arbitrary.arbitrary[Seq[InterruptLatency]]
    jtp       <- Arbitrary.arbitrary[Seq[JobThroughput]]
  } yield Benchmark(java.nio.file.Paths.get("N/A"), timestamp, host, lv, tsm, il, jtp)
  implicit val arbBenchmark: Arbitrary[Benchmark] = Arbitrary(benchmarkGen)

  /* Generators and Arbitraries @} */
}
// vim: foldmethod=marker foldmarker=@{,@} foldlevel=0
