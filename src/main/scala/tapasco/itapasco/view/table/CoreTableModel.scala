package de.tu_darmstadt.cs.esa.tapasco.itapasco.view.table
import  de.tu_darmstadt.cs.esa.tapasco.itapasco.globals._
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt._
import  de.tu_darmstadt.cs.esa.tapasco.task._
import  de.tu_darmstadt.cs.esa.tapasco.util.Listener
import  scala.swing._
import  javax.swing.table._
import  scala.collection.mutable.{Set => MSet}

/**
 * Table model for the Cores main table:
 * The cores main table provides several functions:
 *
 *   1. Shows available Cores/Kernels
 *   2. Shows which Cores/Kernels are available for which Target
 *   3. Enables the user to start HLS task for missing Cores
 *   4. Enables user to configure the composition
 *
 * The required information is drawn from both the FileAssetManager and the
 * current UserConfigurationModel. CoreTableModel automatically tracks
 * changes to these objects and updates itself accordingly.
 **/
class CoreTableModel extends AbstractTableModel {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private val _isBuilding: MSet[(String, Target)] = MSet()
  import CoreTableModel._
  // listen to changes and fire update events
  FileAssetManager += new Listener[FileAssetManager.Event] {
    import FileAssetManager.Events._, Entities._
    def update(e: FileAssetManager.Event): Unit = e match {
      case BasePathChanged(_, _) =>
        _logger.trace("received event: {}", e)
        fireTableStructureChanged()
      case EntityChanged(`Cores`, _, _) =>
        _logger.trace("received event: {}", e)
        fireTableDataChanged()
      case EntityChanged(`Kernels`, _, _) =>
        _logger.trace("received event: {}", e)
        fireTableDataChanged()
      case ReportChanged(_, _) =>
        _logger.trace("received event: {}", e)
        fireTableDataChanged()
      case _ => fireTableStructureChanged()
    }
  }

  Config += new Listener[Config.Event] {
    def update(e: Config.Event) {
      _logger.trace("received event: {}", e)
      fireTableStructureChanged()
      fireTableDataChanged()
    }
  }

  Job += new Listener[Job.Event] {
    def update(e: Job.Event) {
      _logger.trace("received event: {}", e)
      fireTableStructureChanged()
      fireTableDataChanged()
    }
  }

  TaskScheduler += new Listener[Tasks.Event] {
    import Tasks.Events._
    import java.nio.file._

    private val waitForZips: scala.collection.mutable.Map[Path, (Kernel, Target)] =
      scala.collection.mutable.Map()

    def update(e: Tasks.Event): Unit = e match {
      case TaskStarted(_, t) => t match {
        case ht: HighLevelSynthesisTask =>
          startedBuilding(ht.k.name, ht.t)
          waitForZips += ht.synthesizer.outputZipFile(ht.k, ht.t)(ht.cfg) -> (ht.k, ht.t)
        case _ => {}
      }
      case TaskCompleted(_, t) => t match {
        case it: ImportTask =>
          waitForZips.get(it.zip) foreach { case (k, t) => finishedBuilding(k.name, t) }
        case _ => {}
      }
      case _ => {}
    }
  }

  /**
   * Inform model that name if currently building for target.
   * Buildable will remain false while at least one build is
   * in flight.
   * @param name Name of the kernel.
   * @param target Target the kernel is being build for.
   **/
  def startedBuilding(name: String, target: Target): Unit = {
    _isBuilding += ((name, target))
    fireTableDataChanged()
  }

  /**
   * Inform model that building of name for target has finished.
   * Buildable will remain false while at least one build is
   * in flight.
   * @param name Name of the kernel.
   * @param target Target the kernel is being build for.
   **/
  def finishedBuilding(name: String, target: Target): Unit = {
    _isBuilding -= ((name, target))
    fireTableDataChanged()
  }

  /** Returns true, if at least one build of name is in flight. */
  def isBuilding(name: String): Boolean = _isBuilding.exists(_._1 equals name)

  override def getRowCount(): Int = getData().length
  override def getColumnCount(): Int = 3 + Job.job.targets.size
  override def getColumnName(col: Int): String = mkHead(col)
  override def getValueAt(row: Int, col: Int): Object = if (col > 0) {
    mkArray(getData())(row)(col)
  } else {
    mkArray(getData())(row)(col).asInstanceOf[NamedDescription].name
  }

  override def setValueAt(o: Object, row: Int, col: Int): Unit = {
    try {
      val i = o.toString.toInt
      if (i >= 0 && i <= Job.job.target.pd.slotCount) {
        // set value in composition
        Job.job = Job.job.copy(
          initialComposition = Job.job.initialComposition.set(Composition.Entry(getData()(row).d.name, i))
        )
      }
    } catch {
      case ex: java.lang.NumberFormatException =>
        _logger.debug("invalid number: {}", o.toString)
    }
  }
  override def isCellEditable(row: Int, col: Int): Boolean =
    (col == 1 && (getData()(row).coreAvailable fold true) (_ && _)) || // Cores are available for all Targets
    (col == getColumnCount() - 1 && getData()(row).buildable)          // or: Build button, if buildable

  private[table] def getData(): Seq[CoreTableRow] = {
    // first get all kernels
    val ks: Seq[NamedDescription] = FileAssetManager.entities.kernels.toSeq.sortBy(_.name)
    def uniquify(s: Set[Core], ret: Set[Core] = Set()): Set[Core] = {
      val n = s.find(e => ! (ret map (_.name) contains e.name))
      if (n.isEmpty) ret else uniquify(s - n.get, ret + n.get)
    }
    // now get one Core desc for all core names which are not in the kernel list
    val cs: Seq[NamedDescription] =
      uniquify(FileAssetManager.entities.cores filter (c => !(ks map (_.name) contains c.name))).toSeq.sortBy(_.name)
    // name list: merge and sort by name
    val ds: Seq[NamedDescription] = (ks ++ cs).toSeq.sortBy(_.name)
    for {
      d <- ds
      count = Job.job.initialComposition.apply(d.name)
      coreAvailable: Array[Boolean] = for {
        t <- Job.job.targets.toArray
      } yield FileAssetManager.entities.core(d.name, t).nonEmpty
      buildable: Boolean = d match {
        case k: Kernel => ! isBuilding(k.name)         &&  // buildable only, if not building yet
                          (coreAvailable exists (! _))     // and at least one core is missing
        case c: Core   => false                            // Cores cannot be build without a Kernel
      }
    } yield CoreTableRow(d, count, coreAvailable, buildable)
  }

  private def mkArray(data: Seq[CoreTableRow]): Array[Array[Object]] = (
    data map { ctr => (Array(ctr.d, ctr.count) ++ ctr.coreAvailable ++ Array(ctr.buildable)) map (_.asInstanceOf[Object]) }
  ).toArray

  private def mkHead: Array[String] = Array("Core", "Count") ++
    FileAssetManager.entities.targets.map(_.toString).toSeq.sorted.toArray[String] ++
    Array("Build")
}

/** Companion object to CoreTableModel: basic types. */
private[table] object CoreTableModel {
  // scalastyle:off structural.type
  /** Named base.subsume Kernel and Core instances. */
  type NamedDescription = Description { def name: String }
  // scalastyle:on structural.type

  /**
   * A data row in the CoreTableModel.
   * @param d Named description object.
   * @param count Number of instances.
   * @param coreAvailable True, if core is found for given target (alphabetically sorted).
   * @param buildable True, if missing Core can be built.
   **/
  sealed case class CoreTableRow(d: NamedDescription, count: Int, coreAvailable: Array[Boolean], buildable: Boolean)
}
