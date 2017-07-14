#!/bin/bash
#
# Copyright (C) 2014 Jens Korinth, TU Darmstadt
#
# This file is part of Tapasco (TPC).
#
# Tapasco is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Tapasco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
#
${CROSS_COMPILE}g++ -o sudoku_mt -std=c++11 -Wall -Werror -g -pthread -I/scratch/jk/rcu/arch/common/include -I/scratch/jk/rcu/platform/common/include -L/scratch/jk/rcu/arch/axi4mm/lib/${ARCH} -L/scratch/jk/rcu/platform/zynq/lib/${ARCH} -lrt -ltapasco -lplatform-client multithreaded.cpp Sudoku.cpp Sudoku_HLS.cpp
