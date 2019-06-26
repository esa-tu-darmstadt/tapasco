package tapasco.reports

import java.nio.file.Path

import tapasco.util.SequenceMatcher

import scala.io.Source

final case class PortReport(override val file: Path, numMasters: Int, numSlaves: Int) extends Report(file)

object PortReport {
  private[this] val logger = tapasco.Logging.logger(this.getClass)

  def apply(pr: Path): Option[PortReport] = extract(pr)

  private def masterPortMatcher: SequenceMatcher[Int] = new SequenceMatcher[Int](
    """AXI_MASTER_PORTS\s+(\d+)""".r
  )(true, ms => ms.head.group(1).toInt)

  private def slavePortMatcher: SequenceMatcher[Int] = new SequenceMatcher[Int](
    """AXI_SLAVE_PORTS\s+(\d+)""".r
  )(true, ms => ms.head.group(1).toInt)

  private def extract(pr: Path): Option[PortReport] = try {
    val numMasters = masterPortMatcher
    val numSlaves = slavePortMatcher
    val source = Source.fromFile(pr.toString)
    source.getLines foreach { line =>
      numMasters.update(line)
      numSlaves.update(line)
    }
    if (numMasters.matched && numSlaves.matched) {
      Some(PortReport(pr, numMasters.result.get, numSlaves.result.get))
    }
    else {
      None
    }
  } catch {
    case e: Exception =>
      logger.warn("Could not extract port information from %s: %s".format(pr, e))
      None
  }

}
