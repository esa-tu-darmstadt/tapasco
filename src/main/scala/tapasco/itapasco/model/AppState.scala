package de.tu_darmstadt.cs.esa.tapasco.itapasco.model
import  de.tu_darmstadt.cs.esa.tapasco.util.Publisher

/**
 * Model of the global state of the iTPC application.
 **/
class AppState extends Publisher {
  type Event = AppState.Event
  private[this] var _state: AppState.State = AppState.States.Normal

  /** Returns the current state. */
  def state: AppState.State = _state

  /** Sets the current state (will publish change event). */
  def state_=(s: AppState.State): Unit = {
    _state = s
    publish(AppState.Events.StateChanged(s))
  }
}

/** Companion object to AppState, contains [[States]] and [[Events]]. */
object AppState {
  sealed trait Event
  final object Events {
    /** Application state has changed. */
    final case class StateChanged(s: State) extends Event
  }

  sealed trait State
  final object States {
    /** "Normal" state: initial state of the application. */
    final case object Normal extends State
    /** DSE state: showing graph, running exploration. */
    final case object DesignSpaceExploration extends State
  }
}
