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
