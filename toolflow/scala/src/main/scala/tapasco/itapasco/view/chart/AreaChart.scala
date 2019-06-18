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
package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.chart
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common.DefaultColors
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{BorderPanel, Component}
import  scala.swing.BorderPanel.Position._
import  org.jfree.chart._
import  org.jfree.chart.plot.PiePlot
import  org.jfree.data.general._
import  java.awt.{Color, Dimension}

// scalastyle:off null
protected[view] class AreaChart(area: Map[String, AreaEstimate], title: Option[String] = None)
    extends BorderPanel {
  import AreaChart._

  private def areaPie: JFreeChart = {
    val ds = new DefaultPieDataset
    val sections = (area.keys).toSeq.sorted.zipWithIndex
    sections foreach { case (name, i) =>
      ds.insertValue(i, name, area(name).resources.LUT)
    }
    val total = area.values reduce (_ + _)
    ds.insertValue((sections map (_._2)).max + 1, "unused",
      total.available.LUT - total.resources.LUT)

    val chart = ChartFactory.createPieChart(title.getOrElse(null), ds)
    chart.setBackgroundPaint(null)
    val plot = chart.getPlot().asInstanceOf[PiePlot]
    plot.setOutlineVisible(false)
    plot.setCircular(true)
    plot.setBackgroundPaint(null)
    plot.setShadowGenerator(null)
    plot.setShadowPaint(null)
    plot.setLabelGap(0.0)
    plot.setLabelBackgroundPaint(LABEL_BG_COLOR)
    sections foreach { case (name, i) =>
      plot.setSectionPaint(name, DefaultColors(i))
      plot.setExplodePercent(name, LABEL_EXPLODE)
    }
    plot.setSectionPaint("unused", UNUSED_COLOR)
    chart
  }

  val c = Component.wrap(new ChartPanel(areaPie))
  c.preferredSize = PREFERRED_SZ
  layout(c) = Center
  revalidate()
}
// scalastyle:on null

private object AreaChart {
  // scalastyle:off magic.number
  final val PREFERRED_SZ         = new Dimension(50, 50)
  final val UNUSED_COLOR         = new Color(64, 64, 64)
  // scalastyle:off magic.number
  final val LABEL_BG_COLOR       = Color.white
  final val LABEL_EXPLODE        = 0.05
}
