package de.tu_darmstadt.cs.esa.tapasco.filemgmt
/** Change type represents changes in files. **/
sealed trait Change
/** Singleton containing all [[Change]] instances. **/
final object Changes {
  /** File was created. **/
  final case object Create extends Change
  /** File was modified. **/
  final case object Modify extends Change
  /** File was deleted. **/
  final case object Delete extends Change
}
