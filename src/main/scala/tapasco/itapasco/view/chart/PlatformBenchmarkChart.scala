package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.DefaultColors
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  scala.swing.{BorderPanel, Component}
import  scala.swing.BorderPanel.Position._
import  org.jfree.chart._
import  org.jfree.data.category._
import  org.jfree.chart.renderer.category._
import  org.jfree.chart.labels._
import  java.awt.{BasicStroke, Color}

// scalastyle:off null
protected[view] class PlatformBenchmarkChart(bm: Benchmark) extends BorderPanel {
  private[this] final val ds = new DefaultCategoryDataset
  private[this] final val PREFERRED_HEIGHT = 200

  bm.transferSpeed foreach { m =>
    ds.addValue(m.read, "r", m.chunkSize / 1024.0)
    ds.addValue(m.write, "w", m.chunkSize / 1024.0)
    ds.addValue(m.readWrite, "rw", m.chunkSize / 1024.0)
  }

  private[this] val bc = ChartFactory.createBarChart(
    null,//"Transfer Speeds",
    null,//"Chunk Size (Byte)",
    null,//"Transfer Speed (Byte/s)",
    ds,
    plot.PlotOrientation.VERTICAL,
    true,
    true,
    false
  )

  val cats = new CategoryItemLabelGenerator {
    def generateColumnLabel(ds: CategoryDataset, column: Int): String =
      "Column"
    def generateLabel(ds: CategoryDataset, row: Int, column: Int): String =
      "Label"
    def generateRowLabel(ds: CategoryDataset, row: Int): String = "Row"
  }

  val ttg = new CategoryToolTipGenerator {
    def generateToolTip(ds: CategoryDataset, row: Int, column: Int): String = {
      val v = ds.getValue(row, column)
      val m = Seq("read:", "write:", "readwrite:")(row)
      val c = bm.transferSpeed(column).chunkSize
      val csStr = "%d %s".format(
        if (c / 1024 > 1024) c / (1024 * 1024) else c / 1024,
        if (c / 1024 > 1024) "MiB" else "KiB"
      )
      "%s %3.2f MiB/s @ %s".format(m, v, csStr)
    }
  }

  bc.setBackgroundPaint(null)
  bc.getPlot().setBackgroundPaint(Color.white)
  bc.getCategoryPlot().setRangeGridlinePaint(Color.black)
  val br = bc.getCategoryPlot().getRenderer().asInstanceOf[BarRenderer]
  DefaultColors.toSeq map { c => br.setSeriesPaint(DefaultColors.toSeq.indexOf(c), c) }
  br.setBaseOutlinePaint(Color.black)
  br.setBaseOutlineStroke(new BasicStroke(1.0f))
  br.setMaximumBarWidth(0.333)
  br.setItemMargin(0.0)
  br.setBarPainter(new StandardBarPainter())
  br.setBaseItemLabelGenerator(cats)
  br.setBaseToolTipGenerator(ttg)
  val c = Component.wrap(new ChartPanel(bc))
  c.preferredSize = new java.awt.Dimension(0, PREFERRED_HEIGHT)
  layout(c) = Center
}
// scalastyle:on null
