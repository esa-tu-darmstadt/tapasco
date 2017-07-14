//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file     Alternatives.scala
 * @brief    One dimension for design space exploration are variants or alternatives of
 *           the same kernel, i.e., IP cores that compute the same function using the
 *           same interface, but with different implementations. This can be useful to
 *           evaluate area/performance trade-offs.
 *           This class provides helpers to identify alternatives for cores using their
 *           id; every core with the same id is assumed to implement the same function.
 *           Methods in this class can compute sets of alternatives for cores as well
 *           as all alternatives for an entire composition.
 * @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
package de.tu_darmstadt.cs.esa.tapasco.dse
import  de.tu_darmstadt.cs.esa.tapasco.base._
import  de.tu_darmstadt.cs.esa.tapasco.filemgmt.FileAssetManager
import  java.nio.file.Paths

object Alternatives {
  private[this] val logger = de.tu_darmstadt.cs.esa.tapasco.Logging.logger(this.getClass)

  /** Returns the ID of a given kernel name.
    * @param name Name of the kernel
    * @return ID if found, None otherwise **/
  def idForName(name: String)(implicit cfg: Configuration): Option[Int] = {
    val ks = FileAssetManager.entities.kernels.filter(_.name equals name).headOption.map(_.id)
    lazy val cs = FileAssetManager.entities.cores.filter(_.name == name).headOption.map(_.id)
    if (ks.orElse(cs).isEmpty) logger.warn("Could not find id for '" + name + "'")
    ks.orElse(cs)
  }

  /** Returns all kernel and core names for a given id.
    * @param id Id of the kernel
    * @return set of all names of kernels and cores with id **/
  def namesForId(id: Int)(implicit cfg: Configuration): Set[String] =
    (FileAssetManager.entities.kernels.filter(_.id == id).map(_.name) ++
     FileAssetManager.entities.cores.filter(_.id == id).map(_.name)).toSet

  /** Returns alternative kernel names for given kernel on Target.
    * @param kernel Name of the kernel
    * @param target Target Architecture and Platform
    * @return Set of alternative names for kernel on Target **/
  def alternatives(kernel: String, target: Target)(implicit cfg: Configuration): Set[String] =
    idForName(kernel) map (namesForId(_)) getOrElse(Set())

  /** Returns alternative kernels for given kernel.
   *  @param kernel Kernel to find alternatives to.
   *  @return Set of alternative Kernels. **/
  def alternatives(kernel: Kernel)(implicit cfg: Configuration): Set[Kernel] =
    FileAssetManager.entities.kernels.filter(_.id equals kernel.id)

  /** Returns alternative kernels for given kernel name.
   *  @param name Name of Kernel; this may be used to find alternatives to an Verilog/VHDL core.
   *  @return Set of alternative Kernels. **/
  def alternatives(name: String)(implicit cfg: Configuration): Set[Kernel] =
    FileAssetManager.entities.kernels.filter(k => idForName(name) map (_ equals k.id) getOrElse false)

 /** Returns alternative compositions on given Target.
   * @param bd Original Composition
   * @param target Target for the Composition
   * @return List of alternative compositions with same counts and all alternative
             kernel combinations (beware of combinatorial explosion!) **/
 def alternatives(bd: Composition, target: Target)(implicit cfg: Configuration): Seq[Composition] = {
    def combine[A](xs: Traversable[Traversable[A]]): Seq[Seq[A]] =
      xs.foldLeft(Seq(Seq.empty[A])) { (x,y) => for (a <- x.view; b <- y) yield a :+ b }

    for (ces <- combine(bd.composition map (ce => alternatives(ce.kernel, target) map (Composition.Entry(_, ce.count)))))
      yield Composition(Paths.get(bd.id), Some("generated alternative composition"), ces)
  }
}
