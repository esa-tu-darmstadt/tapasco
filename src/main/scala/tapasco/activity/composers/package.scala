package de.tu_darmstadt.cs.esa.tapasco.activity

/** Composers subpackage: Contains Composer activities.
  * A Composer produces a complete hardware-design from a [[base.Composition]],
  * i.e., a set of [[base.Kernel]] instances and instantiation counts.
  * To this end, a Composer has to construct a full micro-architecture by
  * instantiating the Kernels (each instance is called a processing
  * element, PE) and connecting them to the host and memory.
  * Currently only Vivado Design Suite is supported as a Composer.
  **/
package object composers
