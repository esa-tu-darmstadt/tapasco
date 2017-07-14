package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.config
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.common._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  scala.swing.{Button, BorderPanel, FlowPanel, Orientation, SplitPane, Swing}
import  scala.swing.Swing._
import  scala.swing.event._

/** ConfigPanel shows UI elements to configure a [[jobs.DesignSpaceExplorationJob]].
 *  Each property of the job has to have its own UI representation, leading to a
 *  quite involved Component: Uses two [[common.TripleSplitPanel]]s with a
 *  [[common.DividerSync]] to present a table-like structure, consisting of first
 *  row: Design space dimension (frequency, utilization, alternatives); second
 *  row: batch size, a warning panel (for misconfigurations) and SLURM.
 *  Last row contains a button for the user to start the exploration, which 
 *  raises a corresponding [[ConfigPanel.Event]] (nothing is done directly, MVC
 *  approach better here).
 *
 *  This panel and its subpanels do not follow a clean
 *  ''Model-View-Controller (MVC)'' approach, since all changes are directly
 *  communicated to [[globals.Job]]. But this simplified the panels so
 *  significantly, that it was done anyway.
 *
 *  @todo Support [[base.Feature]] configuration.
 *  @todo Maybe use clean MVC approach again, no globals?
 */
class ConfigPanel extends BorderPanel with Publisher {
  type Event = ConfigPanel.Event
  import ConfigPanel.Events._

  private[this] final val BORDER_SZ = 5
  private[this] val defaultBorder = CompoundBorder(EtchedBorder, EmptyBorder(BORDER_SZ))

  private val targetSelection: TargetSelectionPanel    = new TargetSelectionPanel { border = defaultBorder }
  private val freqVariation: FrequencyVariationPanel   = new FrequencyVariationPanel
  private val utilVariation: UtilizationVariationPanel = new UtilizationVariationPanel
  private val altsVariation: AlternativeVariationPanel = new AlternativeVariationPanel
  private val batchSize: BatchSizePanel                = new BatchSizePanel
  private val slurm: SlurmPanel                        = new SlurmPanel
  private val warn: WarningPanel                       = new WarningPanel
  val startButton                              = new Button("Start Design Space Exploration") {
    enabled = Job.job.initialComposition.nonEmpty && Job.job.targets.nonEmpty
  }
  val start: FlowPanel                         = new FlowPanel { contents += startButton; border = defaultBorder }

  private val row0 = new TripleSplitPanel(freqVariation, utilVariation, altsVariation)
  private val row1 = new TripleSplitPanel(batchSize, warn, slurm)
  private val ds   = new DividerSync(row0, row1)
  private val main = new SplitPane(Orientation.Horizontal) {
    leftComponent  = row0
    rightComponent = row1
    border = None.orNull
    dividerSize = 2
  }

  private def updateDividers() = Swing.onEDT {
    row0.dividerLocations.left  = 0.5
    row0.dividerLocations.right = 2.0 / 3.0
    row1.dividerLocations.left  = 0.5
    row1.dividerLocations.right = 2.0 / 3.0
    main.dividerLocation        = 0.85
  }

  layout(targetSelection) = BorderPanel.Position.North
  layout(main)            = BorderPanel.Position.Center
  layout(start)           = BorderPanel.Position.South
  listenTo(this, startButton)

  reactions += {
    case UIElementResized(e) => if (e.equals(this)) updateDividers()
    case ButtonClicked(`startButton`) => publish(ExplorationStartRequested)
  }

  Job += new Listener[Job.Event] {
    import Job.Events._
    def update(e: Job.Event): Unit = e match {
      case JobChanged(job) =>
        startButton.enabled = job.initialComposition.nonEmpty && job.targets.nonEmpty
      case _ => {}
    }
  }
}

object ConfigPanel {
  sealed trait Event
  object Events {
    /** Raised when the user clicks the button to start the exploration. */
    final case object ExplorationStartRequested extends Event
  }
}
