package de.tu_darmstadt.cs.esa.tapasco.itapasco.executables
import  de.tu_darmstadt.cs.esa.tapasco.dse.log._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.DesignSpaceExplorationJob
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.controller._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  scala.swing.{BorderPanel, Frame, MainFrame, SimpleSwingApplication, Swing}

/** Reads a DSE Json logfile and shows an [[controller.ExplorationGraphController]]
 *  for it.
 *  Each DSE run produces a logfile in Json format, which can be "replayed" into
 *  an [[model.DesignSpaceGraph]], which in turn can be displayed by the 
 *  [[controller ExplorationGraphController]]. This applications shows a window
 *  containing only the graph view of the DSE page in iTPC and allows to browse
 *  through past DSE runs conveniently
 *
 *  @note First argument should be the file name.
 */
object LogViewer extends SimpleSwingApplication {
  private val egc = new ExplorationGraphController
  private final val WINDOW_SZ = 300

  override def top: Frame = new MainFrame {
    title = "Design Space Exploration Log Viewer"
    preferredSize = new java.awt.Dimension(WINDOW_SZ, WINDOW_SZ)
    contents = new BorderPanel {
      layout(egc.view) = BorderPanel.Position.Center
    }
  }

  override def startup(args: Array[String]) {
    super.startup(args)
    FileAssetManager.start()
    if (args.length > 0) {
      val log = ExplorationLog.fromFile(args(0))
      log foreach { case (cfg, l) =>
        Config.configuration = cfg
        (cfg.jobs collect {
          case j: DesignSpaceExplorationJob => j
        }).lastOption foreach { Job.job = _ }
        egc.egp.elog.setLogEvents(l)
        ExplorationLog += Graph.graph
        ExplorationLog.replay(l)
        ExplorationLog -= Graph.graph
      }

      Swing.onEDT {
        Graph.publish(Graph.Events.GraphChanged)
      }
    } else {
      throw new Exception("expected Json log file as argument")
    }
  }
}
