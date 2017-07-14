package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection.core._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.detail._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager.Events._
import  de.tu_darmstadt.cs.esa.tapasco.jobs.HighLevelSynthesisJob
import  de.tu_darmstadt.cs.esa.tapasco.jobs.executors._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.slurm._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Dialog, FileChooser}
import  javax.swing.filechooser.FileFilter
import  CorePanelController._

/** Controls a [[view.selection.core.CorePanel]] instance.
 *  Most complex of the view controllers, facilitates several user interactions:
 *
 *   - core table shows unified list of [[base.Kernel]] and [[base.Core]] instances:
 *     Each PE id has its own line, showing whether or not the PE hardware module
 *     is available for each of the selected [[base.Target]]s; if one is missing,
 *     the last column shows a button to trigger HLS execution for the PE.
 *     If the PE is available for all selected [[base.Target]]s, then the 'count'
 *     column can be used to enter the number of instance in the Composition.
 *   - If the composition is non-empty, a summary panel will be displayed which
 *     shows the estimated area utilization on each [[base.Target]].
 *   - The 'Import' button facilitates the import of existing IP-XACT .zip files.
 *
 *   The detail view below shows charts concerning the area utilization and estimated
 *   F_max of each PE on each [[base.Target]].
 *
 *   @todo Import is missing ID, avg. clock cycles - need to add user dialogs.
 *
 *   @constructor Create new instance.
 */
class CorePanelController extends {
  val cores   = new CorePanel
  val details = new CoreDetailPanel
} with SelectionDetailViewController(ViewController(cores), ViewController(details)) {
  private[this] implicit final val _logger =
   de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  // details view should listen to selection view
  cores += details

  private def importCore(): Unit = {
    if (ImportFileChooser.showOpenDialog(cores) == FileChooser.Result.Approve) {
      _logger.trace("selected zip: {}", ImportFileChooser.selectedFile.toString)
      val path = java.nio.file.Paths.get(ImportFileChooser.selectedFile.toString)
      val tasks = for {
        t <- Job.job.targets
      } yield new ImportTask(path, t, 1, None, b => cores.update())(Config.configuration) // FIXME missing ID, clock cycles
      tasks foreach (TaskScheduler.apply _)
    }
  }

  private def hls(k: Kernel) {
    import scala.concurrent.Future
    import scala.concurrent.ExecutionContext.Implicits.global
    _logger.debug("launching HLS job for {}", k)

    if (Slurm.available && !Slurm.enabled) {
      Slurm.enabled = Dialog.showConfirmation(view, "SLURM batch mode is available. Use SLURM?",
          "Use SLURM?") == Dialog.Result.Yes
    }

    implicit val cfg: Configuration = Config.configuration
    implicit val tsk: Tasks = TaskScheduler

    _logger.trace("starting HLS execution in background ...")
    Future {
      HighLevelSynthesisJob(
        _implementation = "VivadoHLS",              // Vivado HLS by default
        _architectures = Job.job.architectureNames, // all selected Architectures
        _platforms = Job.job.platformNames,         // all selected Platforms
        _kernels = Some(Seq(k.name))                // only Kernel k
      ).execute
    }
    _logger.trace("HLS running for {}", k)
  }

  cores += new Listener[CorePanel.Event] {
    import CorePanel.Events._
    def update(e: CorePanel.Event): Unit = e match {
      case ImportRequest => importCore()
      case HighLevelSynthesisRequest(k) => hls(k)
      case _ => {}
    }
  }

  FileAssetManager += new Listener[FileAssetManager.Event] {
    def update(e: FileAssetManager.Event): Unit = e match {
      case BasePathChanged(_, _)  => cores.update()
      case EntityChanged(_, _, _) => cores.update()
      case _ => {}
    }
  }
}

private object CorePanelController {
  object ImportFileChooser extends FileChooser() {
    title = "Choose IP-XACT archive to import"
    fileSelectionMode = FileChooser.SelectionMode.FilesOnly
    fileFilter = new FileFilter {
      def accept(path: java.io.File): Boolean = !path.isFile() || path.getName().endsWith(".zip")
      def getDescription(): String = "IP-XACT IP Core Archives (.zip)"
    }
  }
}
