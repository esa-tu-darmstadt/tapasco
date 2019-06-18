package tapasco

import java.nio.file.{Path, Paths}

package object base {
  def jsonSubfolder : String = "src/test/resources/json-examples"
  def jsonPath : Path = Paths.get(jsonSubfolder).toAbsolutePath
}
