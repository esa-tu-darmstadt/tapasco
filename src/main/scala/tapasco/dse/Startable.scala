package de.tu_darmstadt.cs.esa.tapasco.dse
import  java.util.concurrent.CountDownLatch

private trait Startable {
  def start(signal: Option[CountDownLatch] = None): Unit
  def start(signal: CountDownLatch): Unit = start(Some(signal))
}
