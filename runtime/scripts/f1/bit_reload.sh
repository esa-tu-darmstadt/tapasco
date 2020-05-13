#!/bin/bash
#
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

# init paths
DRIVER=tlkm
DRIVERPATH="$TAPASCO_HOME_RUNTIME/kernel"

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|--drv-reload] AGFI-ID
Program FPGA on an F1 cloud instance.

	-v	enable verbose output
	-d	reload device driver
	-p	program the device
EOF
}

# init vars
BITSTREAM=""
VERBOSE=0
RELOADD=0
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
		p)
			PROGRAM=1
			;;
		h)
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
if [ -n $BITSTREAM ] && [[ $BITSTREAM == agfi* ]]
then
	echo "AGFI = $BITSTREAM"

	if ! type -P "fpga-load-local-image" ; then
		echo "Command 'fpga-load-local-image' not found."
		echo "Please download the AWS F1 HDK and run 'source sdk_setup.sh'."
		exit 1
	fi

	# unload driver, if reload_driver was set
	if [ $RELOADD -gt 0 ]; then
		sudo rmmod $DRIVER
	fi

	# program the device
	if [ $PROGRAM -gt 0 ]; then
		sudo fpga-load-local-image -S 0 -I "$BITSTREAM" -H
	fi

	# reload driver?
	if [ $RELOADD -gt 0 ]; then
		sudo insmod $DRIVERPATH/${DRIVER}.ko
		sudo chown $USER /dev/tlkm*
	fi

	# output tail of dmesg in verbose mode
	if [ $VERBOSE -gt 0 ]; then
		dmesg | tail -7
	fi
else
	show_usage
	exit 1
fi
