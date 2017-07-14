package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.executables._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base.Configuration
import  de.tu_darmstadt.cs.esa.tapasco.base.json._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.DesignSpaceExplorationJob
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.AppState
import  scala.swing.{Dialog, FileChooser, Swing}
import  java.nio.file._

/** Main controller of iTPC.
 *  AppController is the outermost controller of iTPC. It uses a subordinate
 *  [[ConfigurationPanelController]] to control the main configuration panel.
 *
 *  @constructor Create new controller instance.
 *  @param oc [[base.Configuration]] instance (optional).
 */
class AppController(oc: Option[Configuration]) {
  private[this] val _cfgc  = new ConfigurationPanelController
  private[this] val _app   = new Tapasco(_cfgc)
  TaskScheduler += _app.statusPanel
  _app.mainMenu.Publisher += AppMenuListener

  /** Shows the main view. */
  def show(): Unit = _app.main(Array())

  /** Loads a new [[base.Configuration]] instance, updating all subviews. */
  def loadConfiguration() {
    val fc = new FileChooser(Paths.get(".").toFile) {
      title = "Choose TPC configuration file to load"
      fileSelectionMode = FileChooser.SelectionMode.FilesOnly
    }
    if (fc.showOpenDialog(_app.mainPanel) == FileChooser.Result.Approve) {
      setConfig(Configuration.from(Paths.get(fc.selectedFile.toString)).toOption)
    }
  }

  /** Saves the current configuration, including the DSE configuration.
   *  Displays a file choosing dialog for the user to select the output file.
   */
  def saveConfiguration() {
    val fc = new FileChooser(Paths.get(".").toFile) {
      title = "Choose file to save TPC configuration file in"
      fileSelectionMode = FileChooser.SelectionMode.FilesOnly
    }
    if (fc.showSaveDialog(_app.mainPanel) == FileChooser.Result.Approve) {
      val cfg: Configuration = Config.configuration
      try {
        Configuration.to(cfg, Paths.get(fc.selectedFile.toString)).swap foreach { throw _ }
      } catch { case ex: java.io.IOException =>
        Dialog.showMessage(_app.mainPanel,
          "Failed to save to file %s: %s"
            .format(fc.selectedFile.toString, ex.toString),
          "Error saving configuration")
      }
    }
  }

  /** Exits the application.
   *  If any tasks are running in the background, a confirmation dialog will be shown.
   */
  def exit() {
    if (TaskScheduler.running.size > 0 || Slurm.jobs().length > 0) {
      if(Dialog.showConfirmation(
          _app.mainPanel,
          "There are still tasks running in the background.\n" +
          "External processes (such as Vivado, Vivado HLS) will finish normally, \n" +
          "but other tasks and SLURM jobs will be aborted.\n" +
          "Are you sure you want to exit?",
          "Background tasks running, exit?") == Dialog.Result.Yes) {
        Slurm.cancelAllJobs()
        _app.quit()
      }
    } else {
      _app.quit()
    }
  }

  Swing.onEDT {
    State.state = AppState.States.Normal
    setConfig(oc)
  }

  private def setConfig(oc: Option[Configuration]): Unit = oc foreach { c =>
    Config.configuration = c
    (c.jobs collect { case job: DesignSpaceExplorationJob => job }).lastOption foreach { Job.job = _ }
  }

  private object AppMenuListener extends Listener[AppMenu.Event] {
    import AppMenu.Events._
    def update(e: AppMenu.Event): Unit = e match {
      case LoadConfiguration => loadConfiguration()
      case SaveConfiguration => saveConfiguration()
      case DumpDebugInfo     => {} // TODO implement?
      case Exit              => exit()
    }
  }
}

