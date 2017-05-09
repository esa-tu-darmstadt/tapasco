val tpcVersion = "2017.1-SNAPSHOT"

organization := "de.tu_darmstadt.esa.cs"

version := tpcVersion

name := "ThreadPoolComposer"

scalaVersion := "2.12.1"

libraryDependencies ++= Seq(
  "org.scala-lang" % "scala-compiler" % scalaVersion.value,
  "org.scala-lang" % "scala-reflect" % scalaVersion.value,
  "org.scala-lang.modules" % "scala-swing_2.12" % "2.0.0",
  "org.scala-lang.modules" %% "scala-parser-combinators" % "1.0.4",
  "com.typesafe.play" %% "play-json" % "2.6.0-M3" exclude ("ch.qos.logback", "logback-classic"),
  "org.jfree" % "jfreechart" % "1.0.19",
  "org.slf4j" % "slf4j-api" % "1.7.22",
  "ch.qos.logback" % "logback-classic" % "1.2.1",
  "net.sf.jung" % "jung-api" % "2.1.1",
  "net.sf.jung" % "jung-visualization" % "2.1.1",
  "net.sf.jung" % "jung-graph-impl" % "2.1.1",
  "com.google.guava" % "guava" % "19.0",
  "com.google.code.findbugs" % "jsr305" % "3.0.1",
  "org.scalatest" %% "scalatest" % "3.0.1" % "test",
  "org.scalacheck" %% "scalacheck" % "1.13.4" % "test"
)

scalacOptions ++= Seq(
  "-feature",
  "-language:postfixOps",
  "-language:reflectiveCalls",
  "-deprecation",
  "-Ywarn-unused-import",
  "-Ywarn-infer-any"
)

scalacOptions in Compile ++= Seq(
  "-opt:unreachable-code",
  "-opt:simplify-jumps",
  "-opt:compact-locals",
  "-opt:copy-propagation",
  "-opt:redundant-casts",
  "-opt:box-unbox",
  "-opt:nullness-tracking",
  "-opt:closure-invocations",
  "-opt:l:classpath"/*,
  "-Xelide-below", "3000",
  "-Xdisable-assertions"*/
)

scalacOptions in (Compile,doc) ++= Seq(
  "-diagrams",
  //"-implicits",
  "-implicits-hide:."
)

fork in run := true

val tpc = inputKey[Unit]("Run ThreadPoolComposer command.")

tpc := (runMain in Compile).partialInput (" de.tu_darmstadt.cs.esa.threadpoolcomposer.ThreadPoolComposer ").evaluated

val itpc = InputKey[Unit]("itpc", "Run interactive ThreadPoolComposer GUI.")

fullRunInputTask(itpc, Compile, "de.tu_darmstadt.cs.esa.threadpoolcomposer.ThreadPoolComposer", "itpc")

fork in itpc := true

javaOptions in itpc += "-splash:icon/threadpoolcomposer_icon.png"

val logviewer = inputKey[Unit]("Run interactive DSE log viewer.")

fullRunInputTask(logviewer, Compile, "de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.executables.LogViewer")

javaOptions in logviewer += "-splash:icon/threadpoolcomposer_icon.png"

val reportviewer = inputKey[Unit]("Run interactive report viewer.")

fullRunInputTask(reportviewer, Compile, "de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.executables.ReportViewer")

javaOptions in reportviewer += "-splash:icon/threadpoolcomposer_icon.png"

fork := true

test in assembly := {}

assemblyJarName := "ThreadPoolComposer-" + tpcVersion + ".jar"

parallelExecution in Test := false

fork in Test := false

mainClass in assembly := Some("de.tu_darmstadt.cs.esa.threadpoolcomposer.ThreadPoolComposer")

