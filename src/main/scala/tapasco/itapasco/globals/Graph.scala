package de.tu_darmstadt.cs.esa.tapasco.itapasco.globals
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.model.DesignSpaceGraph
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph._
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.view.dse.graph.jung._
import  de.tu_darmstadt.cs.esa.tapasco.dse._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  edu.uci.ics.jung.algorithms.layout._
import  edu.uci.ics.jung.visualization._
import  edu.uci.ics.jung.visualization.control._
import  DesignSpaceGraph._

/** Global state object tracking the current [[dse.Exploration]] and the corresponding
 *  [[model.DesignSpaceGraph]]. Clients can subscribe to updates.
 */
protected[itapasco] object Graph extends Publisher {
  private final val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private var _exploration: Option[Exploration] = None
  /** The current design space graph instance. */
  val graph: DesignSpaceGraph = new DesignSpaceGraph
  /** Global static layout of the graph. */
  val layout: Layout[N, E] = new DesignSpaceStaticLayout(graph)
  private val vmodel: VisualizationModel[N, E] = new DefaultVisualizationModel[N, E](layout)
  private val vmouse: AbstractModalGraphMouse = new DefaultModalGraphMouse[N, E] {
    setMode(ModalGraphMouse.Mode.TRANSFORMING)
  }
  /** VisualizationViewer for the main graph view. */
  val mainViewer: VisualizationViewer[N, E] = mkMainViewer
  /** VisualizationViewer for the minimap/satellite graph view. */
  val satViewer: VisualizationViewer[N, E] = mkSatViewer

  sealed trait Event
  object Events {
    /** Raised when current [[dse.Exploration]] instance changes. */
    final case class ExplorationChanged(oe: Option[Exploration]) extends Event
    /** Raised when current [[model.DesignSpaceGraph]] instance changes. */
    final case object GraphChanged extends Event
    /** Raised when user picks a node in the `mainViewer`. */
    final case class NodePicked(n: N, picked: Boolean) extends Event
  }
  import Events._

  /** Returns the current [[dse.Exploration]] instance for a running DSE. */
  def exploration: Option[Exploration] = _exploration
  /** Sets the current [[dse.Exploration]] instance for a running DSE. */
  def exploration_=(oe: Option[Exploration]) {
    _exploration foreach { _ -= graph }       // remove graph listener
    graph.clear()                             // reset the graph
    _exploration = oe                         // set new Exploration
    _exploration foreach { _ += graph }       // add graph listener
    publish(ExplorationChanged(_exploration)) // publicize Exploration
    publish(GraphChanged)                     // publicize Graph
  }

  // listen to TaskScheduler to notice when exploration starts
  TaskScheduler += new Listener[Tasks.Event] {
    import Tasks.Events._
    def update(e: Tasks.Event): Unit = e match {
      case TaskStarted(_, t) => t match {
        case et: ExplorationTask =>
          exploration = Some(et.exploration)
          logger.debug("registered new exploration")
        case _ => {}
      }
      case TaskCompleted(_, t) => t match {
        case et: ExplorationTask =>
          logger.debug("exploration finished")
        case _ => {}
      }
      case _ => {}
    }
  }

  private def mkMainViewer: VisualizationViewer[N, E] = new VisualizationViewer(vmodel) {
    import java.awt.event.ItemListener
    setGraphMouse(vmouse)
    addKeyListener(vmouse.getModeKeyListener())
    addPreRenderPaintable(new MainViewerGrid(this))
    new MainGraphStyle(graph, this)(this)
    getPickedVertexState().addItemListener(new ItemListener {
      import java.awt.event.ItemEvent
      def itemStateChanged(e: ItemEvent) {
        e match {
          case e: ItemEvent =>
            logger.trace("item event: {}", e)
            val n = e.getItem().asInstanceOf[N]
            publish(NodePicked(n, getPickedVertexState().isPicked(n)))
          case _ => {}
        }
      }
    })
  }

  private def mkSatViewer: VisualizationViewer[N, E] = new VisualizationViewer(vmodel) {
    // scalastyle:off magic.number
    private[this] final val BG_COLOR = new java.awt.Color(50, 50, 70)
    // scalastyle:on magic.number
    setBackground(BG_COLOR)
    addPreRenderPaintable(new MainViewerHighlight(this))
    addPreRenderPaintable(new SatelliteViewerGrid(this))
    mainViewer.addChangeListener(this)
    new SatelliteGraphStyle(graph)(this)
  }
}
