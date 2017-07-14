package de.tu_darmstadt.cs.esa.tapasco.parser
import  org.scalacheck._
import  org.scalatest._
import  org.scalatest.prop.Checkers
import  fastparse.all._
import  java.nio.file._
import  Common._

class GlobalOptionsSpec extends FlatSpec with Matchers with Checkers {
  import org.scalacheck.Prop._
  import GlobalOptions._, GlobalOptionsSpec._
  implicit val cfg = new PropertyCheckConfiguration(minSize = 10000, sizeRange = 1000)

  "All strings" should "be parsed correctly by path" in
    check(forAll(pathGen) { p =>
      checkParsed( P( BasicParsers.path ~ End ).parse(p.toString) )
    })

  "All variants of global params" should "be parsed correctly" in
    check(forAllNoShrink(paramStringGen) { ps =>
      checkParsed( P( globalOptionsSeq ~ End ).parse(ps) )
    })

  "All sequences of global params" should "parsed correctly" in
    check(forAllNoShrink(fullStringGen) { fs =>
      checkParsed( P( globalOptionsSeq ~ End ).parse(fs) )
    })
}

private object GlobalOptionsSpec {
  /* @{ Generators and Arbitraries */
  val pathGen: Gen[Path] = for {
    ps <- BasicParserSpec.stringGen
  } yield Paths.get(ps)

  def dirStringGen(base: String): Gen[String] = for {
    s <- BasicParserSpec.genLongOption(base)
    w <- BasicParserSpec.wsStringGen
    p <- BasicParserSpec.qstringGen
  } yield s"$s$w $p"

  val configFileGen: Gen[String]     = dirStringGen("configFile")
  val jobsFileGen: Gen[String]       = dirStringGen("jobsFile")
  val logFileGen: Gen[String]        = dirStringGen("logFile")
  val archDirGen: Gen[String]        = dirStringGen("archDir")
  val platformDirGen: Gen[String]    = dirStringGen("platformDir")
  val compositionDirGen: Gen[String] = dirStringGen("compositionDir")
  val coreDirGen: Gen[String]        = dirStringGen("coreDir")
  val dryRunGen: Gen[String]         = dirStringGen("dryRun")
  val slurmGen: Gen[String]          = BasicParserSpec.genLongOption("slurm")
  val parallelGen: Gen[String]       = BasicParserSpec.genLongOption("parallel")
  val maxThreadsGen: Gen[String]     = BasicParserSpec.join(Seq(
    BasicParserSpec.genLongOption("maxThreads"),
    Gen.posNum[Int] map (_.toString)
  ))

  val paramStringGen: Gen[String] = Gen.oneOf(
    configFileGen,
    jobsFileGen,
    logFileGen,
    archDirGen,
    platformDirGen,
    compositionDirGen,
    coreDirGen,
    dryRunGen,
    maxThreadsGen
  )

  val fullStringGen: Gen[String] = Gen.oneOf(
    BasicParserSpec.wsStringGen,
    for {
      n  <- Gen.choose(0, 20)
      ps <- Gen.buildableOfN[Seq[String], String](n, for {
        p <- paramStringGen
        s <- BasicParserSpec.wsStringGen
      } yield s" $p $s")
      e <- paramStringGen
    } yield (ps :+ e).mkString
  ) 
  /* Generators and Arbitraries @} */
}
