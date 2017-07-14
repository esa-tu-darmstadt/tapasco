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

show_usage() {
	cat << EOF
Usage: ${0##*/} [-v|--verbose] [--d|--drv-reload] BITSTREAM
Program FPGA via /dev/xdevcfg.

	-v	enable verbose output
	-d	reload device driver
EOF
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
if [ -n $BITSTREAM ] && [[ $BITSTREAM == *.bit ]] && [[ -e $BITSTREAM ]]
then
	pushd $TAPASCO_HOME/platform/zynq/module &> /dev/null
	if [[ `lsmod | grep tapasco | wc -l` -eq 1 ]]; then
	sudo ./unload.sh
	fi
	popd &> /dev/null
	echo "Loading bitstream $BITSTREAM ..."
	sudo sh -c "cat $BITSTREAM > /dev/xdevcfg"
	echo "Done!"
	pushd $TAPASCO_HOME/platform/zynq/module &> /dev/null
	echo "Loading kernel module ..."
	sudo ./load.sh
	popd &> /dev/null
	echo "Done."
else
	show_usage
	exit 1
fi
