package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  scala.swing.{GridPanel, Label}

/** Panel that displays an estimation for area utilization and max. frequency for
 *  the given Composition on the given Target.
 *
 *  @note Currently all reports must be available (requirement).
 *  @todo Safe-guard against missing data, present 'no data' hint instead.
 *
 *  @constructor Create new instance.
 *  @param cfg [[base.Configuration]] instance.
 *  @param c [[base.Composition]] to show summaries for.
 *  @param t [[base.Target]] to provide estimates for.
 */
class CompositionTargetSummaryPanel(cfg: Configuration, c: Composition, t: Target) extends GridPanel(3, 1) {
  implicit val _cfg = cfg
  private[this] val _reports = c.composition flatMap { ce =>
    FileAssetManager.reports.synthReport(ce.kernel, t.ad.name, t.pd.name)
  }
  require(_reports.length > 0, "must have at least one report!")

  /** Max. frequency for `c` on `t`. */
  val maxFrequency =
    1000.0 / (_reports flatMap (_.timing) map (_.clockPeriod)).max

  /** Area estimation for `c` on `t`. */
  val totalArea =
    (_reports flatMap (_.area) zip (c.composition map (_.count))) map {
      case (a, c) => a * c
    } reduce (_ + _)

  /** Area utilization for `c` on `t` (in percent). */
  val utilization = totalArea.utilization

  /** Feasibility for `c` on `t`. */
  val feasible = totalArea.isFeasible

  contents += new Label("%s@%s".format(t.pd.name, t.ad.name))
  contents += new Label("~%d%% LUTs".format(utilization.toInt)) {
    if (! feasible) foreground = java.awt.Color.red
  }
  contents += new Label("%d MHz (max.)".format(maxFrequency.toInt))
}
