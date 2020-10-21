/*
 *
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
/**
  * @file SlurmRemoteConfig.scala
  * @brief Model: TPC remote Slurm Configuration.
  * @authors M. Hartmann, TU Darmstadt
  **/

package tapasco.base

import java.nio.file.Path
import tapasco.base.builder.Builds

case class SlurmRemoteConfig(
                              name: String,
                              host: String,
                              workstation: String,
                              workdir: Path,
                              installdir: Path,
                              jobFile: String
                            )

object SlurmRemoteConfig extends Builds[SlurmRemoteConfig]
