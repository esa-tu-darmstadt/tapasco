package de.tu_darmstadt.cs.esa.tapasco.filemgmt
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.reports._
import  de.tu_darmstadt.cs.esa.tapasco.util._
import  java.nio.file._

/**
 * A ReportManager maintains caches for different report types in a common base
 * directory: Currently co-simulation, timing, power and synthesis reports
 * are supported, each in an [[EntityCache]] of their own.
 *
 * To react on changes, the basePathListener and directoryListener values
 * should be registered with a [[BasePathManager]] and a [[DirectoryWatcher]].
 * @param _base Initial base path, e.g., TAPASCO_HOME/core.
 **/
class ReportManager(var _base: Path) extends Publisher {
  import Entities._
  type Event = EntityCache.Event
  private[this] final val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)

  /** Reset all caches. */
  def reset(): Unit = { _reportCaches foreach { _.clear() } }

  /** Clear caches and set optional new paths. */
  def clear(p: Option[Set[Path]] = None): Unit = _reportCaches foreach { _.clear(p) }

  /* @{ Listeners */
  /** Listener for base path changes: will react to changes of Cores dir. */
  val basePathListener = new Listener[BasePathManager.Event] {
    def update(e: BasePathManager.Event): Unit = e match {
      case BasePathManager.BasePathChanged(`Cores`, np) =>
        _base = np
        _reportCaches foreach { _.clear(Some(Set(_base))) }
      case _ => {}
    }
  }

  /** Listener for directory watcher events: will forward to all caches. */
  val directoryListener = new Listener[DirectoryWatcher.Event] {
    def update(e: DirectoryWatcher.Event): Unit = _reportCaches foreach { _.update(e) }
  }
  /* Listeners @} */

  /* @{ report accessors */
  /** Returns all CoSimReports. **/
  def cosimReports: Set[CoSimReport] = _cosimReportCache.entities
  /** Returns CoSimReport for given core and target. **/
  def cosimReport(name: String, target: Target): Option[CoSimReport] =
    cosimReport(name, target.ad.name, target.pd.name)
  /** Returns CoSimReport for given core and Architecture/Platform combination. **/
  def cosimReport(name: String, archName: String, platformName: String): Option[CoSimReport] = {
    val bp = _base.resolve(name).resolve(archName).resolve(platformName)
    _logger.trace("looking for CoSimReport of {}@{}@{} in {}", name, archName, platformName, bp)
    val files = _cosimReportCache.files filter (f => f.startsWith(bp))
    if (files.size > 1) {
      _logger.warn("found more than one CoSimReport of {}@{}@{} in {}: {}",
        name, archName, platformName, bp, files)
    }
    files.headOption flatMap { f => _cosimReportCache.apply(f).head }
  }

  /** Returns all PowerReports. **/
  def powerReports: Set[PowerReport] = _powerReportCache.entities
  /** Returns PowerReport for given core and target. **/
  def powerReport(name: String, target: Target): Option[PowerReport] =
    powerReport(name, target.ad.name, target.pd.name)
  /** Returns PowerReport for given core and Architecture/Platform combination. **/
  def powerReport(name: String, archName: String, platformName: String): Option[PowerReport] = {
    val bp = _base.resolve(name).resolve(archName).resolve(platformName)
    _logger.trace("looking for PowerReport of {}@{}@{} in {}", name, archName, platformName, bp)
    val files = _powerReportCache.files filter (f => f.startsWith(bp))
    if (files.size > 1) {
      _logger.warn("found more than one PowerReport of {}@{}@{} in {}: {}",
        name, archName, platformName, bp, files)
    }
    files.headOption flatMap { f => _powerReportCache.apply(f).head }
  }

  /** Returns all SynthesisReports. **/
  def synthReports: Set[SynthesisReport] = _synthReportCache.entities
  /** Returns SynthesisReport for given core and target. **/
  def synthReport(name: String, target: Target): Option[SynthesisReport] =
    synthReport(name, target.ad.name, target.pd.name)
  /** Returns SynthesisReport for given core and Architecture/Platform combination. **/
  def synthReport(name: String, archName: String, platformName: String): Option[SynthesisReport] = {
    val bp = _base.resolve(name).resolve(archName).resolve(platformName)
    _logger.trace("looking for SynthesisReport of {}@{}@{} in {}", name, archName, platformName, bp)
    val files = _synthReportCache.files filter (f => f.startsWith(bp))
    if (files.size > 1) {
      _logger.warn("found more than one SynthesisReport of {}@{}@{} in {}: {}",
        name, archName, platformName, bp, files)
    }
    files.headOption flatMap { f => _synthReportCache.apply(f).head }
  }

  /** Returns all TimingReports. **/
  def timingReports: Set[TimingReport] = _timingReportCache.entities
  /** Returns TimingReport for given core and target. **/
  def timingReport(name: String, target: Target): Option[TimingReport] =
    timingReport(name, target.ad.name, target.pd.name)
  /** Returns TimingReport for given core and Architecture/Platform combination. **/
  def timingReport(name: String, archName: String, platformName: String): Option[TimingReport] = {
    val bp = _base.resolve(name).resolve(archName).resolve(platformName)
    _logger.trace("looking for TimingReport of {}@{}@{} in {}", name, archName, platformName, bp)
    val files = _timingReportCache.files filter (f => f.startsWith(bp))
    if (files.size > 1) {
      _logger.warn("found more than one TimingReport of {}@{}@{} in {}: {}",
        name, archName, platformName, bp, files)
    }
    files.headOption flatMap { f => _timingReportCache.apply(f).head }
  }
  /* @} */

  /** EntityCache instance for CoSimReports. **/
  private val _cosimReportCache = EntityCache(Set(_base),
      """_cosim.rpt$""".r.unanchored, CoSimReport.apply _)
  /** EntityCache instance for PowerReports. **/
  private val _powerReportCache = EntityCache(Set(_base),
      """power.rpt$""".r.unanchored, PowerReport.apply _)
  /** EntityCache instance for SynthesisReports. **/
  private val _synthReportCache = EntityCache(Set(_base),
      """_export.xml$""".r.unanchored, SynthesisReport.apply _)
  /** EntityCache instance for TimingReports. **/
  private val _timingReportCache = EntityCache(Set(_base),
      """timing.rpt$""".r.unanchored, TimingReport.apply _)

  /** Internal seq of report caches. **/
  private val _reportCaches: Seq[EntityCache[_]] = Seq(
    _cosimReportCache,
    _powerReportCache,
    _synthReportCache,
    _timingReportCache
  )

  private val _entityCacheListener = new Listener[EntityCache.Event] {
    // just forward all events
    def update(e: EntityCache.Event): Unit = publish(e)
  }

  _reportCaches foreach { _ += _entityCacheListener }

  def dump(osw: java.io.OutputStreamWriter): Unit = {
    import scala.util.Properties.{lineSeparator => NL}
    osw.append("<<ReportEntityCache: CoSim>>").append(NL)
    EntityCache.dump(_cosimReportCache, osw)
    osw.append(NL)
    osw.append("<<ReportEntityCache: Power>>").append(NL)
    EntityCache.dump(_powerReportCache, osw)
    osw.append(NL)
    osw.append("<<ReportEntityCache: Synth>>").append(NL)
    EntityCache.dump(_synthReportCache, osw)
    osw.append(NL)
    osw.append("<<ReportEntityCache: Timing>>").append(NL)
    EntityCache.dump(_timingReportCache, osw)
    osw.append(NL)
  }
}
// vim: foldmarker=@{,@} foldmethod=marker foldlevel=0
