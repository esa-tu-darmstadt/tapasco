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
DRIVER=tlkm
DRIVERPATH="$TAPASCO_HOME/tlkm"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|--drv-reload] BITSTREAM
Program Zynq PL via /dev/xdevcfg.

	-v	enable verbose output
	-d	reload device driver
EOF
}

# init vars
BITSTREAM=""
VERBOSE=0
RELOADD=0

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
	cat $BITSTREAM > /dev/xdevcfg
	XDEVCFG_RET=$?

	# check return code
	if [ $XDEVCFG_RET -ne 0 ]; then
		echo "programming failed, returned non-zero exit code $XDEVCFG_RET"
		exit $XDEVCFG_RET
	fi
	echo "bitstream programmed successfully!"

	# reload driver?
	if [ $RELOADD -gt 0 ]; then
		sudo insmod $DRIVERPATH/${DRIVER}.ko
	fi

else
	show_usage
	exit 1
fi
