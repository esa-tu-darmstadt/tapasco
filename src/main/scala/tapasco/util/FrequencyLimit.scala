package de.tu_darmstadt.cs.esa.tapasco.util
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  scala.collection.mutable.Map

/**
 * Helper object to compute timing estimates for [[base.Core]] and [[base.Composition]] instances.
 **/
object FrequencyLimit {
  private[this] val _logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(getClass)
  private[this] val _coreMemos: Map[Configuration, Memoization[(Target, Core), Option[TimingEstimate]]] = Map()
  private[this] val _compoMemos: Map[Configuration, Memoization[(Target, Composition), Option[TimingEstimate]]] = Map()

  /** Compute timing estimate for given Core on given Target. */
  def apply(target: Target, cd: Core)(implicit cfg: Configuration): Option[TimingEstimate] =
    (if (! _coreMemos.contains(cfg)) {
      val memo = new Memoization((computeCoreFreq _).tupled)
      _coreMemos += cfg -> memo
      memo
    } else {
      _coreMemos(cfg)
    }) (target, cd)

  /** Compute timing estimate for given Composition on given Target. */
  def apply(target: Target, bd: Composition)(implicit cfg: Configuration): Option[TimingEstimate] =
    (if (! _compoMemos.contains(cfg)) {
      val memo = new Memoization((computeCompositionFreq _).tupled)
      _compoMemos += cfg -> memo
      memo
    } else {
      _compoMemos(cfg)
    }) (target, bd)

  private def computeCoreFreq(target: Target, cd: Core)(implicit cfg: Configuration): Option[TimingEstimate] =
    FileAssetManager.reports.synthReport(cd.name, target) flatMap (_.timing)

  private def computeCompositionFreq(target: Target, bd: Composition)(implicit cfg: Configuration): Option[TimingEstimate] = {
    assert (bd.composition.length > 0, "composition must not be empty")
    val cores   = bd.composition flatMap { ce => FileAssetManager.entities.core(ce.kernel, target) }
    val periods = cores flatMap (apply(target, _))
    // check if all required data is available
    if (cores.length < bd.composition.length) {
      _logger.warn("could not find all core base. no frequency estimate for composition")
      None
    } else if (periods.length < bd.composition.length) {
      _logger.warn("could not find all synthesis reports, no frequency estimate for composition")
      None
    } else {
      // return TimingEstimate with maximal period (lowest frequency)
      Some(periods.max)
    }
  }
}
