val tapascoVersion = "2019.6"

organization := "de.tu_darmstadt.esa.cs"

version := tapascoVersion

name := "Tapasco"

scalaVersion := "2.12.7"

libraryDependencies ++= Seq(
  "org.scala-lang" % "scala-compiler" % scalaVersion.value,
  "org.scala-lang" % "scala-reflect" % scalaVersion.value,
  "org.scala-lang.modules" % "scala-swing_2.12" % "2.0.1",
  "com.typesafe.play" %% "play-json" % "2.6.7" exclude ("ch.qos.logback", "logback-classic"),
  "org.jfree" % "jfreechart" % "1.0.19",
  "org.slf4j" % "slf4j-api" % "1.7.25",
  "ch.qos.logback" % "logback-classic" % "1.2.3",
  "net.sf.jung" % "jung-api" % "2.1.1",
  "net.sf.jung" % "jung-visualization" % "2.1.1",
  "net.sf.jung" % "jung-graph-impl" % "2.1.1",
  "com.google.guava" % "guava" % "19.0",
  "com.google.code.findbugs" % "jsr305" % "3.0.1",
  "org.scalatest" %% "scalatest" % "3.0.4" % "test",
  "org.scalacheck" %% "scalacheck" % "1.13.5" % "test",
  "com.lihaoyi" %% "fastparse" % "1.0.0"
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
  "-opt:inline",
  "-opt:l:inline",
  "-opt-inline-from",
  "-opt:unreachable-code",
  "-opt:simplify-jumps",
  "-opt:compact-locals",
  "-opt:copy-propagation",
  "-opt:redundant-casts",
  "-opt:box-unbox",
  "-opt:nullness-tracking",
  "-opt:closure-invocations"/*,
  "-Xelide-below", "3000",
  "-Xdisable-assertions"*/
)

scalacOptions in (Compile,doc) ++= Seq(
  "-diagrams",
  //"-implicits",
  "-implicits-hide:."
)

fork in run := true

val tapasco = inputKey[Unit]("Run Tapasco command.")

val itapasco = InputKey[Unit]("itapasco", "Run interactive Tapasco GUI.")

val logviewer = inputKey[Unit]("Run interactive DSE log viewer.")

val reportviewer = inputKey[Unit]("Run interactive report viewer.")

tapasco := (runMain in Compile).partialInput (" de.tu_darmstadt.cs.esa.tapasco.Tapasco ").evaluated

fullRunInputTask(itapasco, Compile, "de.tu_darmstadt.cs.esa.tapasco.Tapasco", "itapasco")

fullRunInputTask(logviewer, Compile, "de.tu_darmstadt.cs.esa.tapasco.itapasco.executables.LogViewer")

fullRunInputTask(reportviewer, Compile, "de.tu_darmstadt.cs.esa.tapasco.itapasco.executables.ReportViewer")

fork := true

fork in itapasco := true

fork in Test := false

parallelExecution in Test := false

javaOptions in itapasco += "-splash:icon/tapasco_icon.png"

javaOptions in logviewer += "-splash:icon/tapasco_icon.png"

javaOptions in reportviewer += "-splash:icon/tapasco_icon.png"

test in assembly := {}

assemblyJarName := "Tapasco-" + tapascoVersion + ".jar"

mainClass in assembly := Some("de.tu_darmstadt.cs.esa.tapasco.Tapasco")

def writeScripts(jar: String, base: String) {
  val N = scala.util.Properties.lineSeparator
  val basePath = java.nio.file.Paths.get(base)
  val binPath  = basePath.resolve("bin")
  val iconPath = basePath.resolve("icon").resolve("tapasco_icon.png")
  val tapasco  = binPath.resolve("tapasco")
  val itapasco = binPath.resolve("itapasco")
  val logviewer= binPath.resolve("tapasco-logviewer")
  val rptviewer= binPath.resolve("tapasco-reportviewer")

  var f = new java.io.FileWriter(tapasco.toString)
  f.append("#!/bin/bash").append(N)
   .append("java -Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled -jar %s $*".format(jar)).append(N)
  f.close()
  tapasco.toFile.setExecutable(true)

  f = new java.io.FileWriter(itapasco.toString)
  f.append("#!/bin/bash").append(N)
   .append("java -Xms512M -Xmx1536M -Xss1M -XX:+CMSClassUnloadingEnabled ")
   .append("-splash:%s ".format(iconPath.toString))
   .append("-jar %s ".format(jar))
   .append("itapasco $*").append(N)
  f.close()
  itapasco.toFile.setExecutable(true)

  f = new java.io.FileWriter(logviewer.toString)
  f.append("#!/bin/bash").append(N)
   .append("cd $TAPASCO_HOME && sbt logviewer $*")
  f.close()
  logviewer.toFile.setExecutable(true)

  f = new java.io.FileWriter(rptviewer.toString)
  f.append("#!/bin/bash").append(N)
   .append("cd $TAPASCO_HOME && sbt reportviewer $*")
  f.close()
  rptviewer.toFile.setExecutable(true)
}

cleanFiles ++= Seq(
  baseDirectory.value / "bin" / "tapasco",
  baseDirectory.value / "bin" / "itapasco",
  baseDirectory.value / "bin" / "tapasco-logviewer",
  baseDirectory.value / "bin" / "tapasco-reportviewer",
  baseDirectory.value / "tapasco-status-cache"
)

lazy val root = (project in file("."))
  .settings(
    assembly := (Def.taskDyn {
      val a = assembly.value
      val jar = target(_ / ("scala-" + scalaBinaryVersion.value) /  assemblyJarName.value)
      Def.task {
        writeScripts(jar.value.toString, baseDirectory.value.toString)
        a
      }
    }).value
  )
