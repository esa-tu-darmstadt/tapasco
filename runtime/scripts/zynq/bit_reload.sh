#!/bin/bash
##
## Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
##
## This file is part of TaPaSCo 
## (see https://github.com/esa-tu-darmstadt/tapasco).
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Lesser General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Lesser General Public License for more details.
##
## You should have received a copy of the GNU Lesser General Public License
## along with this program. If not, see <http://www.gnu.org/licenses/>.
##

# Script can run without parameters, use verbose as second for output,
# partial if you want to use a partial bitstream or reload if you want
# to reload the driver.
# Hotplug and program parameter are only for compatability with pcie bit_reload.sh and do nothing.
# Script usage e.g. ./bit_reload 'path_to_bitstream' --verbose
# Pathes '*_path' have to be adapted to specific location
# Works for Zynq and ZynqMP

set -e

# init paths
DRIVER=tlkm
DRIVERPATH="$TAPASCO_HOME_RUNTIME/kernel"
VFIO_RST_REQ="/sys/module/vfio_platform/parameters/reset_required"
VFIO_UNSAFE_INTR="/sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|drv_reload] [-pb|--partial] BITSTREAM.{bit,bin}
Program Zynq PL via /sys/class/fpga_manager/.

	-v	enable verbose output
	-d	reload device driver
	-n	do not load device driver
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
NOLOADD=0
HOTPLUG=0
PARTIAL=0
PROGRAM=0

OPTIND=1
while getopts vdnhp opt; do
	case $opt in
		v)
			VERBOSE=1
			;;
		d)
			RELOADD=1
			;;
		n)
			NOLOADD=1
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

	# always reload driver for correct interrupt controller initialization
	if [ `lsmod | grep $DRIVER | wc -l` -gt 0 ]; then
		echo "unloading tlkm"
		sudo rmmod $DRIVER
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
	if [ $NOLOADD -eq 0 ]; then
		if ! lsmod | grep $DRIVER > /dev/null; then
			sudo insmod $DRIVERPATH/${DRIVER}.ko
			INSMOD_RET=$?
			sudo chown $USER /dev/tlkm*

			# check return code
			if [ $INSMOD_RET -ne 0 ]; then
				echo "Loading driver failed, returned non-zero exit code $INSMOD_RET"
			else
				echo "Driver loaded successfully!"
			fi

			if [ ! -f "$VFIO_RST_REQ" ] || [ "$(cat $VFIO_RST_REQ)" != "N" ]; then
				echo "VFIO configuration error! Need to add bootarg 'vfio_platform.reset_required=0'"
			else
				# register tapasco device with VFIO
				sudo sh -c "echo vfio-platform > /sys/bus/platform/devices/tapasco/driver_override"
				sudo sh -c "echo tapasco > /sys/bus/platform/drivers_probe"
				PROBE_RET=$?
				if [ $PROBE_RET -ne 0 ]; then
					echo "Probing VFIO platform driver failed, returned non-zero exit code $PROBE_RET"
				else
					echo "VFIO loaded successfully!"
				fi
			fi

			# is required on the zcu102
			if [ -f "$VFIO_UNSAFE_INTR" ] && [ "$(cat $VFIO_UNSAFE_INTR)" == "N" ]; then
				sudo sh -c "echo Y > $VFIO_UNSAFE_INTR"
			fi
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
