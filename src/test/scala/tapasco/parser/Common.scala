package de.tu_darmstadt.cs.esa.tapasco.parser
import  fastparse.all._

private object Common {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  def checkParsed(p: => Parsed[_]): Boolean = try { p match {
    case _: Parsed.Success[_] => true
    case r: Parsed.Failure =>
      logger.error("parser exception: " + CommandLineParser.ParserException(r))
      false
  } } catch { case t: Throwable =>
    logger.warn("got throwable: {} - check if this is ok", t)
    true
  }
}
