package de.tu_darmstadt.cs.esa.tapasco
import  org.slf4j.{LoggerFactory}
import  scala.util.control.Exception._

object Logging {
  type Logger = org.slf4j.Logger
  def logger(c: Class[_]): Logger = LoggerFactory.getLogger(c)
  def logger(n: String): Logger = LoggerFactory.getLogger(n)
  def rootLogger: ch.qos.logback.classic.Logger =
    LoggerFactory.getLogger(org.slf4j.Logger.ROOT_LOGGER_NAME).asInstanceOf[ch.qos.logback.classic.Logger]

  def catchAllDefault[T](default: T, prefix: String = "")(body: => T)(implicit logger: Logger): T =
    (handling (classOf[Exception]) by (logDefault[T](default, prefix)(logger)(_))).apply(body)

  def catchDefault[T](default: T, es: Seq[Class[_]], prefix: String = "")
                     (body: => T)
                     (implicit logger: Logger): T =
    (handling (es: _*) by (logDefault[T](default, prefix)(logger)(_))).apply(body)

  private def logDefault[T](default: T, prefix: String)(logger: Logger)(t: Throwable) = {
    logger.warn("%s%s".format(prefix, t))
    logger.debug("%sstacktrace:\n%s".format(prefix, t.getStackTrace() mkString "\n"))
    default
  }
}
