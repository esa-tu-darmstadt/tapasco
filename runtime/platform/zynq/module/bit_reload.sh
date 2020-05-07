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

# Script can run without parameters, use verbose as second for output,
# partial if you want to use a partial bitstream or reload if you want
# to reload the driver.
# Hotplug and program parameter are only for compatability with pcie bit_reload.sh and do nothing.
# Script usage e.g. ./bit_reload 'path_to_bitstream' --verbose
# Pathes '*_path' have to be adapted to specific location
# Works for Zynq and ZynqMP

# init paths
DRIVER=tlkm
DRIVERPATH="$TAPASCO_HOME_RUNTIME/kernel"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|drv_reload] [-pb|--partial] BITSTREAM.{bit,bin}
Program Zynq PL via /sys/class/fpga_manager/.

	-v	enable verbose output
	-d	reload device driver
	-pb	partial bitstream
EOF
}

error_exit() {
	echo ${1:-"unknown error"} >&2 && exit 1
}

# init vars
BITSTREAM=""
VERBOSE=0
RELOADD=0
HOTPLUG=0
PARTIAL=0
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
		pb)
			PARTIAL=1
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
shift "$((OPTIND - 1))"

BITSTREAM="$1"
if [ -n $BITSTREAM ] && [[ $BITSTREAM == *.bit || $BITSTREAM == *.bin ]]; then
	echo "Starting FPGA programming..."
	echo "Bitstream = $BITSTREAM"

	# check if pga_manager framework is installed and a fpga instance exists
	if ! ls /sys/class/fpga_manager/fpga* 1> /dev/null 2>&1; then
		error_exit "Could not find fpga_manager instance under /sys/class/fpga_manager/fpga*."
	fi

	#if reload: unload driver if already running
	if [[ $RELOADD -gt 0 ]]; then
		(lsmod | grep $DRIVER > /dev/null) && sudo rmmod $DRIVER 2> /dev/null
	fi

	# set flag for partial/full bitstream. 0 == full, 1 == partial
	echo $PARTIAL | sudo tee /sys/class/fpga_manager/fpga0/flags > /dev/null

	# copy bitstream to make it available to fpga_manager
	sudo mkdir -p /lib/firmware
	sudo cp $BITSTREAM /lib/firmware/

	# program the device
	basename $BITSTREAM | sudo tee /sys/class/fpga_manager/fpga0/firmware > /dev/null
	FPGA_MANAGER_RET=$?

	# check return code
	if [ $FPGA_MANAGER_RET -ne 0 ]; then
		echo "programming failed, returned non-zero exit code $FPGA_MANAGER_RET"
		exit $FPGA_MANAGER
	fi
	echo "Bitstream programmed successfully!"

	# load driver if not already running
	if ! lsmod | grep $DRIVER > /dev/null; then
		sudo insmod $DRIVERPATH/${DRIVER}.ko
		INSMOD_RET=$?
		sudo chown $USER /dev/tlkm*

		# check return code
		if [ $INSMOD_RET -ne 0 ]; then
			echo "Loading driver failed, returned non-zero exit code $INSMOD_RET"
		else
			echo "Driver loaded sucessfully!"
		fi
	fi

	# remove copied .bit
	sudo rm /lib/firmware/$(basename $BITSTREAM)

	# output tail of dmesg in verbose mode
	if [ $VERBOSE -gt 0 ]; then
		dmesg | tail -7
	fi

else
	show_usage
	exit 1
fi
