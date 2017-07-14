package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.DefaultColors
import  de.tu_darmstadt.cs.esa.tapasco.reports.SynthesisReport
import  scala.swing.{BorderPanel, Component}
import  scala.swing.BorderPanel.Position._
import  org.jfree.chart._
import  org.jfree.data.category._
import  org.jfree.chart.renderer.category._
import  org.jfree.chart.labels._
import  java.awt.{BasicStroke, Color, Dimension}

// scalastyle:off null
protected[view] class SynthesisReportsChart(srs: Map[String, SynthesisReport]) extends BorderPanel {
  import SynthesisReportChart._
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  private def wrap(chart: JFreeChart): Component = {
    val c = Component.wrap(new ChartPanel(chart) {
      override val preferredSize = new Dimension(PREFERRED_WIDTH, PREFERRED_HEIGHT)
    })
    c
  }

  private def mkToolTipGenerator() = new CategoryToolTipGenerator {
    def generateToolTip(ds: CategoryDataset, row: Int, col: Int): String = {
      val key = ds.getRowKey(row)
      srs.get(key.toString) map { r =>
        r.area map { area =>
          lazy val rs = Array(area.resources.SLICE, area.resources.LUT, area.resources.FF,
            area.resources.DSP, area.resources.BRAM)
          lazy val as = Array(area.available.SLICE, area.available.LUT, area.available.FF,
            area.available.DSP, area.available.BRAM)
          "%s: %d / %d".format(key, rs(col), as(col))
        } getOrElse ""
      } getOrElse ""
    }
  }

  private def mkItemLabelGenerator() = new StandardCategoryItemLabelGenerator {
    override def generateLabel(ds: CategoryDataset, row: Int, col: Int): String =
      "%3.1f%%".format(ds.getValue(ds.getRowKey(row), ds.getColumnKey(col)))
  }

  private def areaChart: JFreeChart = {
    val ds = new DefaultCategoryDataset
    srs map { case (k, r) =>
      r.area map { area =>
        ds.addValue(area.slice, k, "Slices (%)")
        ds.addValue(area.lut, k, "LUTs (%)")
        ds.addValue(area.ff, k, "FlipFlops (%)")
        ds.addValue(area.dsp, k, "DSP slices (%)")
        ds.addValue(area.bram, k, "BRAM (%s)")
        _logger.trace("{} => {}", k: Any, area.toString:Any)
      }
    }
    val chart = ChartFactory.createBarChart(
      null,
      null,
      null,
      ds,
      plot.PlotOrientation.VERTICAL,
      true,
      true,
      false
    )

    val ttg = mkToolTipGenerator()
    val cilg = mkItemLabelGenerator()

    chart.setBackgroundPaint(null)
    chart.getPlot().setBackgroundPaint(Color.white)
    chart.getCategoryPlot().setRangeGridlinePaint(Color.black)
    val br = chart.getCategoryPlot().getRenderer().asInstanceOf[BarRenderer]
    DefaultColors.toSeq map { c => br.setSeriesPaint(DefaultColors.toSeq.indexOf(c), c) }
    br.setBaseOutlinePaint(Color.black)
    br.setBaseOutlineStroke(new BasicStroke(1f))
    br.setItemMargin(0.0)
    br.setBarPainter(new StandardBarPainter())
    br.setBaseToolTipGenerator(ttg)
    br.setBaseItemLabelGenerator(cilg)
    br.setBaseItemLabelsVisible(true)
    br.setBasePositiveItemLabelPosition(new ItemLabelPosition(ItemLabelAnchor.OUTSIDE6, org.jfree.ui.TextAnchor.BOTTOM_CENTER))
    br.setItemLabelAnchorOffset(-5.0)
    br.setBaseItemLabelPaint(Color.white)
    chart
  }

  private def timingChart: JFreeChart = {
    val ds = new DefaultCategoryDataset
    srs map { case (k, r) =>
      r.timing map { timing => ds.addValue(1000 / timing.clockPeriod, k, "Fmax (MHz)") }
    }
    val chart = ChartFactory.createBarChart(
      null,
      null,
      null,
      ds,
      plot.PlotOrientation.VERTICAL,
      true,
      true,
      false
    )

    val ttg = new CategoryToolTipGenerator {
      def generateToolTip(ds: CategoryDataset, row: Int, col: Int): String = {
        val key = ds.getRowKey(row)
        srs.get(key.toString) map { r =>
          r.timing map { timing =>
            "%s: %3.1f (T = %2.1f ns)".format(key, 1000 / timing.clockPeriod, timing.clockPeriod)
          } getOrElse ""
        } getOrElse ""
      }
    }

    val cilg = new StandardCategoryItemLabelGenerator {
      override def generateLabel(ds: CategoryDataset, row: Int, col: Int): String =
        "%3.1f".format(ds.getValue(ds.getRowKey(row), ds.getColumnKey(col)))
    }

    chart.setBackgroundPaint(null)
    chart.getPlot().setBackgroundPaint(BG_COLOR)
    chart.getCategoryPlot().setRangeGridlinePaint(GRID_COLOR)
    val br = chart.getCategoryPlot().getRenderer().asInstanceOf[BarRenderer]
    DefaultColors.toSeq map { c => br.setSeriesPaint(DefaultColors.toSeq.indexOf(c), c) }
    br.setBaseOutlinePaint(BASE_OUTLINE_DRAW)
    br.setBaseOutlineStroke(BASE_OUTLINE_STROKE)
    br.setItemMargin(0.0)
    br.setBarPainter(new StandardBarPainter())
    br.setBaseToolTipGenerator(ttg)
    br.setBaseItemLabelGenerator(cilg)
    br.setBaseItemLabelsVisible(true)
    br.setBasePositiveItemLabelPosition(new ItemLabelPosition(ItemLabelAnchor.OUTSIDE6, org.jfree.ui.TextAnchor.BOTTOM_CENTER))
    br.setItemLabelAnchorOffset(-5.0)
    br.setBaseItemLabelPaint(Color.white)
    chart
  }

  layout(wrap(areaChart)) = Center
  layout(wrap(timingChart)) = East
  revalidate()
}
// scalastyle:on null

private object SynthesisReportChart {
  final val PREFERRED_WIDTH           = 300
  final val PREFERRED_HEIGHT          = 100
  final val BG_COLOR                  = Color.white
  final val GRID_COLOR                = Color.black
  final val BASE_OUTLINE_DRAW         = Color.black
  final val BASE_OUTLINE_STROKE_WIDTH = 1f
  final val BASE_OUTLINE_STROKE       = new BasicStroke(BASE_OUTLINE_STROKE_WIDTH)
}
