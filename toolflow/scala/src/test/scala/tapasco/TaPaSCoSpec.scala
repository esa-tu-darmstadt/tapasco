package tapasco

import java.nio.file.{Path, Paths}

import org.junit.runner.RunWith
import org.scalatest.FlatSpec
import org.scalatest.junit.JUnitRunner

@RunWith(classOf[JUnitRunner])
class TaPaSCoSpec extends FlatSpec {
  protected final val jsonDirectory : String = "src/test/resources/json-examples"
  protected final val jsonPath : Path = Paths.get(jsonDirectory).toAbsolutePath
  protected final val reportPath = Paths.get("src/test/resources/report-examples").toAbsolutePath
}
