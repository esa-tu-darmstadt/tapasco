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
 * @file     VLNV.scala
 * @brief    Model for Version-Library-Vendor-Version string identifier.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.util.matching.Regex
import  java.nio.file._

/** Vendor-Library-Name-Version identifier. */
final case class VLNV(vendor: String, library: String, name: String, version: VLNV.Version) {
  override def toString(): String = List(vendor, library, name, version).mkString(":")
}

object VLNV {
  final private val VLNV_REGEX = new Regex("([^:]+):([^:]+):([^:]+):([^:]+)", "vendor", "library", "name", "version")

  final case class Version(major: Int, minor: Int, revision: Option[Int]) {
    override def toString(): String =
      if (revision.isEmpty) { List(major, minor).mkString(".") }
      else                  { List(major, minor, revision).mkString(".") }
  }

  object Version {
    private final val VERSION_REGEX = new Regex("""(\d+).(\d+)(.(\d+))?""")
    def apply(version: String): Version = version match {
      case VERSION_REGEX(major, minor, _, revision) => Version(major.toInt, minor.toInt, Option(revision).map(_.toInt))
      case invalid => throw new Exception("Invalid version string: " + invalid)
    }
  }

  def apply(vlnv: String): VLNV = vlnv match {
    case VLNV_REGEX(vendor, library, name, version) => VLNV(vendor, library, name, Version(version))
    case invalid => throw new Exception("Invalid VLNV string: " + invalid)
  }

  def fromZip(path: Path): VLNV = {
    assert(path.toFile.exists)
    import java.io._
    import java.util.zip._
    try {
      val zip = new ZipInputStream(new BufferedInputStream(new FileInputStream(path.toFile)))
      var zipEntry = Option(zip.getNextEntry())
      var vlnv: String = ""

      while (zipEntry.nonEmpty && !zipEntry.get.toString().endsWith("component.xml"))
        zipEntry = Option(zip.getNextEntry())

      if (zipEntry.nonEmpty) {
        val xml = scala.xml.XML.load(zip)
        val vendor: String = ((xml \ "vendor") map (e => e.text)).head
        val library: String = ((xml \ "library") map (e => e.text)).head
        val name: String = ((xml \ "name") map (e => e.text)).head
        val ver: String = ((xml \ "version") map (e => e.text)).head
        vlnv = List(vendor, library, name, ver).mkString(":")
      } else {
        throw new Exception("Could not find component.xml in " + path)
      }
      zip.close()
      VLNV(vlnv)
    } catch {
      case x: Exception => throw new Exception("Could not read VLNV from " + path.toString + ": " + x.toString)
    }
  }
}
