//
// Copyright (C) 2017 Jens Korinth, TU Darmstadt
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
 * @file     ZipUtils.scala
 * @brief    Helper functions to work with .zip files.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.util
import  de.tu_darmstadt.cs.esa.tapasco.Logging.Logger
import  scala.util.matching._
import  java.nio.file._

object ZipUtils {
  /** Unpacks all files matching the given regular expressions into a temporary directory.
   *  @param zipFile Path to .zip file.
   *  @param regexes List of regexes; all matching files will be extracted.
   *  @return tuple (temporary directory, list of extracted files).
   */
  def unzipFile(zipFile: Path, regexes: Seq[Regex], exclude: Seq[Regex] = Seq())
               (implicit logger: Logger): (Path, Seq[Path]) = {
    import java.util.zip._
    import java.io.{BufferedInputStream, BufferedOutputStream, FileInputStream, FileOutputStream}
    var extracted: List[Path] = List()
    val zis = new ZipInputStream(new BufferedInputStream(new FileInputStream(zipFile.toFile)))
    // scalastyle:off null
    val tempdir = Files.createTempDirectory(null)
    val bufsz = 1024
    // scalastyle:on null
    try {
      var zipEntry = zis.getNextEntry()
      while (Option(zipEntry).nonEmpty) {
        logger.trace(zipFile + ": zipentry: " + zipEntry)
        if ((regexes map (r => ! r.findFirstIn(zipEntry.toString()).isEmpty) reduce(_||_)) &&
            (exclude map (r => r.findFirstIn(zipEntry.toString()).isEmpty) reduce (_&&_))) {
          logger.trace(zipFile + ": extracting " + zipEntry)
          val buffer = new Array[Byte](bufsz)
          val outname = tempdir.resolve(Paths.get(zipEntry.getName()).getFileName()).toString()
          val dest = new BufferedOutputStream(new FileOutputStream(outname), bufsz)
          extracted = Paths.get(outname) :: extracted
          var count = 0
          while ({count = zis.read(buffer, 0, bufsz); count != -1})
            dest.write(buffer, 0, count);
          dest.flush()
          dest.close()
        } else {
          logger.trace(zipFile + ": skipping " + zipEntry)
        }
        zipEntry = zis.getNextEntry()
      }
    } finally {
      zis.close()
    }
    (tempdir, extracted)
  }

  /** Packs all given files into a zipFile.
   *  Throws IOException if something fails.
   *  @param zipFile Path to output zip file.
   *  @param files Sequence of files to pack.
   */
  def zipFile(zipFile: Path, files: Seq[Path]) = {
    import java.util.zip._
    import java.io.{BufferedOutputStream, FileOutputStream}
    val zos = new ZipOutputStream(new BufferedOutputStream(new FileOutputStream(zipFile.toFile)))
    files foreach { f =>
      val ze = new ZipEntry(f.toFile.getName)
      zos.putNextEntry(ze)
      var amountRead: Int = 0
      zos.write(Files.readAllBytes(f))
    }
    zos.flush()
    zos.close()
  }
}
