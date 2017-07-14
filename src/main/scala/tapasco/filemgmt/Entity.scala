package de.tu_darmstadt.cs.esa.tapasco.filemgmt

/**
 * Base class of entities in the TPC flow:
 * Covers all objects which are defined dynamically by description files,
 * e.g., Platforms, Architectures, Kernels.
 **/
sealed trait Entity

/** Singleton object containing all [[Entity]] instances. **/
final object Entities {
  final case object Architectures extends Entity
  final case object Cores         extends Entity
  final case object Compositions  extends Entity
  final case object Kernels       extends Entity
  final case object Platforms     extends Entity

  def apply(): Seq[Entity] = Seq(Architectures, Cores, Compositions, Kernels, Platforms)
}

