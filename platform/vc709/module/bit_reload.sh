#!/bin/bash
#
# Copyright (C) 2017 Jens Korinth, TU Darmstadt
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

# Script can run without parameters, use verbose as second for output and
# drv_load/drv_reload driver, when driver should be inserted
# Script usage e.g. ./bit_reload 'path_to_bitstream' drv_reload verbose  
# Pathes '*_path' have to be adapted to specific location

# init paths
DRIVER=ffLink
DRIVERPATH="$TAPASCO_HOME/platform/vc709/module"
BITLOAD_SCRIPT="$TAPASCO_HOME/platform/vc709/module/program_vc709.tcl"
LOG_ID=$DRIVER"|""pci"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|--drv-reload] BITSTREAM
Program first VC709 found in JTAG chain with BITSTREAM.

	-v	enable verbose output
	-d	reload device driver
EOF
}

hotplug() {
	VENDOR=10EE
	DEVICE=7038
	PCIEDEVICE=`lspci -d $VENDOR:$DEVICE | sed -e "s/ .*//"`
	echo "hotplugging device: $PCIEDEVICE"
	# remove device, if it exists
	if [ -n "$PCIEDEVICE" ]; then
		sudo sh -c "echo 1 >/sys/bus/pci/devices/0000:$PCIEDEVICE/remove"
	fi

	# Scan for new hotplugable device, like the one may deleted before
	sudo sh -c "echo 1 >/sys/bus/pci/rescan"
	echo "hotplugging finished"
}

# init vars
BITSTREAM=""
VERBOSE=0
RELOADD=1

OPTIND=1
while getopts vd opt; do
	case $opt in
		v)
			VERBOSE=1
			;;
		d)
			RELOADD=1
			;;
		*)
			echo "unknown option: $opt"
			show_usage
			exit 1
			;;
	esac
done
shift "$((OPTIND-1))"

BITSTREAM="$1"
if [ -n $BITSTREAM ] && [[ $BITSTREAM == *.bit ]]
then
	echo "bitstream = $BITSTREAM"

	# unload driver, if reload_driver was set
	if [ $RELOADD -gt 0 ]; then
		sudo rmmod $DRIVER
	fi

	# program the device
	if [ $VERBOSE -gt 0 ]; then
		vivado -nolog -nojournal -notrace -mode tcl -source $BITLOAD_SCRIPT -tclargs $BITSTREAM
		VIVADORET=$?
	else
		echo "programming bitstream silently, this could take while ..."
		vivado -nolog -nojournal -notrace -mode batch -source $BITLOAD_SCRIPT -tclargs $BITSTREAM > /dev/null
		VIVADORET=$?
	fi

	# check return code
	if [ $VIVADORET -ne 0 ]; then
		echo "programming failed, Vivado returned non-zero exit code $VIVADORET"
		exit $VIVADORET
	fi
	echo "bitstream programmed successfully!"

	# hotplug the bus
	hotplug

	# reload driver?
	if [ $RELOADD -gt 0 ]; then
		sudo insmod $DRIVERPATH/${DRIVER}.ko
		sudo chown $USER /dev/FFLINK*
	fi

	# output tail of dmesg in verbose mode
	if [ $VERBOSE -gt 0 ]; then
		dmesg | tail -7 | grep -iE $LOG_ID
	fi
else
	show_usage
	exit 1
fi
