package de.tu_darmstadt.cs.esa.tapasco.itapasco.controller
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.AppState
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.selection._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.TabbedPane.Page
import  java.awt.event.KeyEvent

/** ConfigurationPanelController controls an [[view.ConfigurationPanel]] instance.
 *  Basic concept is a TabPane with approx. one tab per step in the overall workflow,
 *  ordered from left to right. The pages currently are:
 *
 *    - 'Directories': Configuration of base paths via [[DirectoriesController]].
 *    - 'Platforms': Selection of [[base.Platform]]s for the run via
 *      [[PlatformsPanelController]].
 *    - 'Architectures': Selection of [[base.Architecture]]s for the run via
 *      [[ArchitecturesPanelController]].
 *    - 'Cores': Configuration of the [[base.Composition]] and HLS via
 *      [[CorePanelController]].
 *    - 'Composition': Pie charts of area estimation overview.
 *    - 'Design Space Exploration': Enabled upon valid composition; configuration
 *      and launch of the DSE, then displays a graph view during run (via
 *      [[ExplorationController]].
 *    - 'Tasks': Task manager, shows queued, running and completed task, provides
 *      log tracking display via [[TasksController]].
 *
 *  @constructor Create new instance of controller.
 */
class ConfigurationPanelController extends ViewController {
  private val cfgv = new ConfigurationPanel

  /** Directories page to configure base paths in TPC. */
  private val dirc = new DirectoriesController
  cfgv.pages += new Page("Directories", dirc.view)

  /** Platforms page to select Platforms. */
  private val plsc = new PlatformsPanelController
  cfgv.pages += new Page("Platforms", plsc.view)
  /** Architectures page to select Architectures. */
  private val arsc = new ArchitecturesPanelController
  cfgv.pages += new Page("Architectures", arsc.view)
  /** Cores page to define a Composition. */
  private val corc = new CorePanelController
  cfgv.pages += new Page("Cores", corc.view)

  /** Composition page to show overview of configured composition. */
  private val composition = new Page("Composition", new CompositionPanel)
  cfgv.pages += composition
  composition.enabled = false

  /** Design space exploration page to configure, start and monitor DSE. */
  private val dsec = new ExplorationController
  private val dse = new Page("Design Space Exploration", dsec.view)
  cfgv.pages += dse
  dse.enabled = false

  /** Tasks special page: Monitor parallel task execution. */
  private val tasksController = new TasksController
  private val taskPage = new Page("Tasks", tasksController.view)
  cfgv.pages += taskPage
  taskPage.background = ConfigurationPanel.TASK_BG_COLOR

  // select all pages once, to initialize the listeners
  cfgv.pages foreach { p =>
    cfgv.selection.page = p
    p.mnemonic = p.title match {
      case "Directories"              => KeyEvent.VK_D
      case "Platforms"                => KeyEvent.VK_P
      case "Architectures"            => KeyEvent.VK_A
      case "Cores"                    => KeyEvent.VK_C
      case "Composition"              => KeyEvent.VK_O
      case "Design Space Exploration" => KeyEvent.VK_X
      case "Tasks"                    => KeyEvent.VK_T
      case _                          => -1
    }
  }
  cfgv.selection.page = cfgv.pages.head

  override val view: View = cfgv
  override val controllers: Seq[ViewController] = Seq(dirc, plsc, arsc, tasksController)

  // update page enables when state changes
  State += new Listener[AppState.Event] {
    import AppState.Events._, AppState.States._, AppState._
    def update(e: AppState.Event): Unit = e match {
      case StateChanged(s: State) =>
        // disable all pages if DSE is running
        cfgv.pages foreach (_.enabled = s != DesignSpaceExploration)
        val enableCompoDeps = Job.job.initialComposition.nonEmpty && Job.job.targets.nonEmpty
        composition.enabled = enableCompoDeps
        dse.enabled = enableCompoDeps
        taskPage.enabled = true
    }
  }

  Job += new Listener[Job.Event] {
    def update(e: Job.Event): Unit = e match {
      case Job.Events.JobChanged(job) =>
        val enableCompoDeps = Job.job.initialComposition.nonEmpty && Job.job.targets.nonEmpty
        composition.enabled = enableCompoDeps
        dse.enabled = enableCompoDeps
    }
  }
}
