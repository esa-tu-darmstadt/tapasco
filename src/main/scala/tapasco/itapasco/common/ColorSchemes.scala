package de.tu_darmstadt.cs.esa.tapasco.itapasco.common
import  java.awt.Color

/** ColorScheme is an addressable set of java.awt.Color definitions. */
trait ColorScheme {
  /** Returns the number of colors in this scheme. */
  def size(): Int
  /** Returns the color at the given index. */
  def apply(index: Int): Color
}

/** DefaultColors is the main color scheme used in the iTPC. */
object DefaultColors extends ColorScheme {
  /** @inheritdoc */
  def size: Int = colors.length
  /** @inheritdoc */
  def apply(index: Int): Color = colors(index % colors.length)
  def toSeq: Seq[Color] = colors

  private val colors = Seq(
    // scalastyle:off magic.number
    new Color(166, 206, 227),
    new Color(31, 120, 180),
    new Color(178, 223, 138),
    new Color(51, 160, 44),
    new Color(251, 154, 153),
    new Color(227, 26, 28),
    new Color(253, 191, 111)
    // scalastyle:on magic.number
  )
}

/** Generic color gradient map:
  * Computes a linear gradient map with multiple stops specified
  * by `cs`. Each element in `cs` contains the color of the stop
  * and its position in the gradient. Widths are relative, i.e.,
  * identical values will produce equidistant stops. Colors are
  * interpolated linearly in their RGB components.
  *
  * @constructor Constructs a new ColorGradientMap.
  * @param cs Sequence of stops defined by a pair of Color and
  *           its relative position (or width).
  **/
class ColorGradientMap(cs: Seq[(Color, Double)]) extends ColorScheme {
  require (cs.nonEmpty, "color list must contain at least one color")
  import de.tu_darmstadt.cs.esa.tapasco.util.Memoization
  // scalastyle:off magic.number
  /** Returns the total number of colors in the gradient index map. */
  def size: Int = 255
  // scalastyle:on magic.number
  /** Returns the `index`'th  color in the sequence (max: [[size]] - 1). */
  def apply(index: Int): Color = apply(index.toDouble / size.toDouble)
  /** Linear interpolation of given colors for positions between 0.0 and 1.0. */
  def apply: Double => Color = new Memoization(findColor _)

  private lazy val (colors, widths) = cs unzip
  private lazy val pos: Seq[Double] = (widths scanLeft 0.0) (_ + _) drop 1
  private lazy val ocs: Seq[(Color, Double)] =
    colors zip (pos map (n => (n - pos.min) / (pos.max - pos.min).toDouble))

  private def findColor(v: Double): Color = {
    val (p, c0, c1) = findPos(v)
    interpolate(p, c0, c1)
  }

  private def interpolate(p: Double, c0: Color, c1: Color) = new Color(
    (c0.getRed() * (1.0 - p) + c1.getRed() * p).toInt,
    (c0.getGreen() * (1.0 - p) + c1.getGreen() * p).toInt,
    (c0.getBlue() * (1.0 - p) + c1.getBlue() * p).toInt)

  // scalastyle:off cyclomatic.complexity
  private def findPos(v: Double, cs: Seq[(Color, Double)] = ocs): (Double, Color, Color) =
    v match {
      case v if v <= 0.0 =>
        (0.0, cs.head._1, cs.head._1)
      case v if v >= 1.0 =>
        (0.0, cs.last._1, cs.last._1)
      case v if v >= cs.head._2 && cs.tail.isEmpty =>
        (0.0, cs.head._1, cs.head._1)
      case v if v >= cs.head._2 && v <= cs.tail.head._2 =>
        ((v - cs.head._2) / (cs.tail.head._2 - cs.head._2), cs.head._1, cs.tail.head._1)
      case v if v >= cs.head._2 && v >= cs.tail.head._2 =>
        findPos(v, cs.tail) // recurse
      case _ => (0.0, cs.head._1, cs.head._1) // fallback for errors
    }
  // scalastyle:on cyclomatic.complexity
}

/** HeatMap based on five colors: Dark blue, bright blue, red, yellow, white.
  * Blues are a bit wider than the rest, white half as wide (no pun intended).
  */
object HeatMap extends ColorGradientMap(Seq(
      // scalastyle:off magic.number
      (new Color(  0,   0,  32), 2.0),
      (new Color(  0,   0, 255), 1.5),
      (new Color(255,   0,   0), 1.0),
      (new Color(224, 224,   0), 1.0),
      (new Color(255, 255, 255), 1.0)
      // scalastyle:on magic.number
    )) {
  /** Compute heat color from given value and min/max.
    * @param min Minimum value in range.
    * @param max Maximum value in range.
    * @param v Value to map.
    * @return Heat color for v.
    */
  def heatToColor(min: Double, max: Double, v: Double): Color =
    apply((v - min) / (max - min))
}

/** Helper object to produce a dump for [[ColorScheme]] instances. */
object ColorSchemeDumper {
  import scala.util.Properties.{lineSeparator => NL}

  /** Dumps an image in NetPBM ASCII format containing the full color rang
    * of the given [[ColorScheme]]. Width and height of the image is the
    * `size` specified by the [[ColorScheme]]. Width may optionally be
    * defined by parameter.
    *
    * @param cs [[ColorScheme]] instance to dump.
    * @param fn File name of the image file to create (may include path).
    * @param width Width of the image (default: `cs.size`).
    **/
  def dump(cs: ColorScheme, fn: String, width: Option[Int] = None): Unit = {
    val fw = new java.io.FileWriter(fn)
    val w = width getOrElse cs.size
    fw.append("P3").append(NL).append("%d %d".format(w, cs.size))
      .append(NL).append("255").append(NL)
    0 until cs.size foreach { i =>
      0 until w foreach { _ =>
        val c = cs(i)
        fw.append("%d %d %d ".format(c.getRed(), c.getGreen(), c.getBlue()))
      }
      fw.append(NL)
    }
    fw.close()
  }
}
// scalastyle:on magic.number
