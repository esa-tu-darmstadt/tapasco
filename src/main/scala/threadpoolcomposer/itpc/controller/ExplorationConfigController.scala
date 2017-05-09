package de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.controller
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.globals._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.itpc.view.dse.config._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.util.Listener
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.base._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.task._
import  de.tu_darmstadt.cs.esa.threadpoolcomposer.slurm._
import  scala.swing.{Dialog}

/** The ExplorationConfigController controls the DSE configuration panel.
 *  It provides UI elements to configure most items on a [[jobs.DesignSpaceExplorationJob]]
 *  and can start a DSE task.
 *
 *  @see [[globals.Job]]
 */
class ExplorationConfigController extends ViewController {
  private final val logger = de.tu_darmstadt.cs.esa.threadpoolcomposer.Logging.logger(getClass)
  private val cfgPanel = new ConfigPanel

  override def view: View = cfgPanel
  override def controllers: Seq[ViewController] = Seq()

  cfgPanel += new Listener[ConfigPanel.Event] {
    import ConfigPanel.Events._
    def update(e: ConfigPanel.Event): Unit = e match {
      case ExplorationStartRequested => startExploration()
    }
  }

  private def startExploration() {
    import de.tu_darmstadt.cs.esa.threadpoolcomposer.jobs.executors._
    import scala.concurrent.Future
    import scala.concurrent.ExecutionContext.Implicits.global
    logger.debug("starting design space exploration ... ")

    if (Slurm.available && !Slurm.enabled) {
      Slurm.enabled = Dialog.showConfirmation(view, "SLURM batch mode is available. Use SLURM?",
          "Use SLURM?") == Dialog.Result.Yes
    }

    implicit val cfg: Configuration = Config.configuration
    implicit val tsk: Tasks = TaskScheduler

    logger.trace("starting DSE execution in background ...")
    Future { Job.job.execute }
    logger.trace("DSE running.")
  }
}
