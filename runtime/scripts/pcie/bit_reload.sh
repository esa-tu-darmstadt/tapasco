#!/bin/bash
# Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
# 
# This file is part of TaPaSCo 
# (see https://github.com/esa-tu-darmstadt/tapasco).
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
# 

# Script can run without parameters, use verbose as second for output and
# drv_load/drv_reload driver, when driver should be inserted
# Script usage e.g. ./bit_reload 'path_to_bitstream' drv_reload verbose
# Pathes '*_path' have to be adapted to specific location

# init paths
DRIVER=tlkm
DRIVERPATH="$TAPASCO_HOME_RUNTIME/kernel"
BITLOAD_SCRIPT="$TAPASCO_HOME_RUNTIME/scripts/pcie/program_pcie.tcl"
LOG_ID=$DRIVER"|""pci"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|--drv-reload] BITSTREAM
Program first supported PCIe based FPGA found in JTAG chain with BITSTREAM.

	-v	enable verbose output
	-d	reload device driver
	-p  program the device
	-h  hotplug the device
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

	sleep 1

	# Scan for new hotplugable device, like the one may deleted before
	sudo sh -c "echo 1 > /sys/bus/pci/rescan"

	PCIEDEVICE=`lspci -d $VENDOR:$DEVICE | sed -e "s/ .*//"`

	if [ -n "$PCIEDEVICE" ]; then
		echo "hotplugging finished"
	else
		echo "ERROR: Could not find the device after hotplugging."
		exit 1
	fi
}

# init vars
BITSTREAM=""
VERBOSE=0
RELOADD=0
HOTPLUG=0
PROGRAM=0

OPTIND=1
while getopts vdhp opt; do
	case $opt in
		v)
			VERBOSE=1
			;;
		d)
			RELOADD=1
			;;
		h)
			HOTPLUG=1
			;;
		p)
			PROGRAM=1
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
	if [ $PROGRAM -gt 0 ]; then

		if [ $VERBOSE -gt 0 ]; then
			vivado -nolog -nojournal -notrace -mode tcl -source $BITLOAD_SCRIPT -tclargs $BITSTREAM
			VIVADORET=$?
		else
			echo "programming bitstream silently, this could take a while ..."
			vivado -nolog -nojournal -notrace -mode batch -source $BITLOAD_SCRIPT -tclargs $BITSTREAM > /dev/null
			VIVADORET=$?
		fi

		# check return code
		if [ $VIVADORET -ne 0 ]; then
			echo "programming failed, Vivado returned non-zero exit code $VIVADORET"
			exit $VIVADORET
		fi
		echo "bitstream programmed successfully!"

	fi

	if [ $HOTPLUG -gt 0 ]; then
		# hotplug the bus
		hotplug
	fi

	# reload driver?
	if [ $RELOADD -gt 0 ]; then
		sudo insmod $DRIVERPATH/${DRIVER}.ko
		sudo chown $USER /dev/tlkm*
	fi

	# output tail of dmesg in verbose mode
	if [ $VERBOSE -gt 0 ]; then
		dmesg | tail -7 | grep -iE $LOG_ID
	fi
else
	show_usage
	exit 1
fi
