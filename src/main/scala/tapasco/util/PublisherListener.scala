package de.tu_darmstadt.cs.esa.tapasco.util
import  scala.collection.mutable.ArrayBuffer
import  scala.language.implicitConversions

/** Listener receives events of type A from a [[Publisher]]. */
trait Listener[A] {
  /** Called by publishers, where this Listener was registered. */
  def update(e: A): Unit
}

/** A Publisher broadcasts events of abstract type [[Publisher.Event]].
 *  [[Listener]] instances can register via its public registrations methods
 *  [[+=]], [[addListener]], [[-=]] and [[remListener]].
 *
 *  '''Example''':
 *  {{{
 *  // define the Publisher
 *  object Something extends Publisher {
 *    // Event type definition
 *    sealed trait Event
 *    // Event instances
 *    final case object ItHappened extends Event
 *    final case object ItHappenedAgain extends Event
 *
 *    ...
 *
 *    def update() {
 *      // publish events
 *      publish(ItHappened)
 *      publish(ItHappenedAgain)
 *    }
 *  }
 *
 *  ...
 *  // later register a Listener:
 *  Something += new Listener[Something.Event] {
 *    // will be called upon publish
 *    def update(e: Event) {
 *      ...
 *    }
 *  }
 *  }}}
 **/
trait Publisher {
  /** Type of events published by this Publisher. */
  type Event

  /** Type alias for listeners. */
  type EventListener = Listener[Event]

  /** Internal array of listeners. */ 
  protected val _listeners: ArrayBuffer[EventListener] = new ArrayBuffer()

  /** Adds an [[EventListener]].
   *  @param el [[EventListener]] instance to register.
   *  @see [[+=]]
   */
  def addListener(el: EventListener) { this += el }

  /** Adds an [[EventListener]].
   *  @param el [[EventListener]] instance to register.
   *  @see [[addListener]]
   */
  def +=(el: EventListener) { _listeners.synchronized { _listeners += el } }

  /** Removes an [[EventListener]].
   *  @param el [[EventListener]] instance to deregister.
   *  @see [[-=]]
   */
  def remListener(el: EventListener) { this -= el }

  /** Removes an [[EventListener]].
   *  @param el [[EventListener]] instance to deregister.
   *  @see [[-=]]
   */
  def -=(el: EventListener): Unit = _listeners.synchronized { _listeners -= el }

  /** Publishes the given event.
   *  @param e [[Event]] to publish.
   **/
  def publish(e: Event) { _listeners.synchronized { _listeners.toSeq } foreach (_.update(e)) }
}

/** Companion object to [[Publisher]]. */
object Publisher {
  /** Implicitly converts a [[Publisher]] to a sequence of its [[Publisher.EventListener]]s.
   *  @note Thread-safe, will return immutable copy.
   */
  implicit def toListenerSeq(p: Publisher): Seq[p.EventListener] =
    p._listeners.synchronized { p._listeners.toSeq }
}
