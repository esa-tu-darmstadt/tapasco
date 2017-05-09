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
BITSTREAM=$1
if [[ "$BITSTREAM" != /* ]]; then
  BITSTREAM=$PWD/$BITSTREAM
fi

if [[ -e $BITSTREAM ]]; then
  pushd $TAPASCO_HOME/platform/zynq/module
  if [[ `lsmod | grep tapasco | wc -l` -eq 1 ]]; then
    sudo ./unload.sh
  fi
  echo "Loading bitstream $BITSTREAM ..."
  sudo sh -c "cat $BITSTREAM > /dev/xdevcfg"
  echo "Done!"
  echo "Loading kernel module ..."
  sudo ./load.sh
  popd
  echo "Done."
else
  echo "ERROR: $BITSTREAM does not exist"
fi

