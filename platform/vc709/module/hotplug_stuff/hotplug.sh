#!/bin/bash
#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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

#set -x
#PATH=$PATH:/sbin

VENDOR=10EE
DEVICE=7038

PCIEDEVICE=`lspci -d $VENDOR:$DEVICE | sed -e "s/ .*//"`

# Look for device, if it exists and remove it (cause its from previous run)
if [ "$PCIEDEVICE" != "" ]; then
sh -c "echo 1 >/sys/bus/pci/devices/0000:$PCIEDEVICE/remove"
#sh -c "echo 1 >/sys/bus/pci/devices/0000:02:00.0/remove"
fi

# Scan for new hotplugable device, like the one may deleted before
sh -c "echo 1 >/sys/bus/pci/rescan"
