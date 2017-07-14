package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  scala.swing._
import  scala.swing.event._
import  scala.swing.BorderPanel.Position._

/** Generic panel for a Slider:
 *  Contains left to right a text label, the slider and a label
 *  showing the current slider value. Triggers a callback on
 *  value change and disables all its components on disable.
 *
 *  @todo Check if this class should be moved to itapasco.common
 *  @param value Initial value for slider.
 *  @param min Minimal value for slider.
 *  @param max Maximal value for slider.
 *  @param valueChanged Callback function for value changes.
 *  @param valueFormat Format function for value label (default: toString).
 *  @param labelText Text for label (optional).
 *  @param tooltip Text for tooltip (optional).
 **/
class SliderPanel(
    svalue: Int,
    smin: Int,
    smax: Int,
    valueChanged: Int => Unit,
    valueFormat: Int => String = _.toString,
    labelText: Option[String] = None,
    toolTip: Option[String] = None) extends BorderPanel {
  private[this] val _slider = new Slider {
    value   = svalue
    min     = smin
    max     = smax
    tooltip = toolTip.getOrElse("")
  }
  private[this] val _label = labelText map (new Label(_))
  private[this] val _value = new Label(valueFormat(_slider.value))

  layout(new FlowPanel {
    _label foreach { contents += _ }
    contents += _slider
    contents += _value
  }) = Center

  listenTo(_slider)
  reactions += {
    case ValueChanged(`_slider`) => {
      _value.text = valueFormat(_slider.value)
      if (! _slider.adjusting) valueChanged(_slider.value)
    }
  }

  override def enabled_=(e: Boolean): Unit = {
    super.enabled = e
    _label foreach (_.enabled = e)
    _slider.enabled = e
    _value.enabled = e
  }

  /** Returns the slider value. */
  def value: Int            = _slider.value
  /** Sets the slider value. */
  def value_=(v: Int): Unit = _slider.value = v
  /** Returns the slider minimum value. */
  def min: Int              = _slider.min
  /** Sets the slider minimum value. */
  def min_=(v: Int): Unit   = _slider.min = v
  /** Returns the slider maximum value. */
  def max: Int              = _slider.max
  /** Sets the slider maximum value. */
  def max_=(v: Int): Unit   = _slider.max = v
}
