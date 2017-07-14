package de.tu_darmstadt.cs.esa.tapasco.util
import  java.util.WeakHashMap
import  scala.collection.JavaConverters._

class Memoization[A, B](f: A => B) extends Function[A, B] {
  private val _memo = new WeakHashMap[A, B]().asScala
  def apply(a: A): B = _memo.synchronized {
    _memo.getOrElse(a, {
      val r = f(a)
      _memo += a -> r
      r
    })
  }

  def remove(a: A): this.type = _memo.synchronized { _memo.remove(a); this }
  def clear(): this.type      = _memo.synchronized { _memo.clear(); this }
}

object Memoization {
  def dump[A, B](m: Memoization[A, B], osw: java.io.OutputStreamWriter): Unit = {
    val NL = scala.util.Properties.lineSeparator
    osw
      .append("<Memoization>").append(NL)
      .append("<<_memo>>").append(m._memo map (_.toString) mkString (NL)).append(NL)
      .append(NL)
  }
}
