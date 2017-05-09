#!/bin/bash
#
# Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
#
# This file is part of ThreadPoolComposer (TPC).
#
# ThreadPoolComposer is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ThreadPoolComposer is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
#

# Script can run without parameters, use verbose as second for output and
# drv_load/drv_reload driver, when driver should be inserted
# Script usage e.g. ./bit_reload 'path_to_bitstream' drv_reload verbose  
# Pathes '*_path' have to be adapted to specific location

# Source vivado scripts for programming
source /opt/cad/xilinx/vivado/Vivado/2015.2/settings64.sh

# save current user name
calling_user=`echo $USER`

# Pathes to needed files
driver_name="ffLink"
driver_path="$TPC_HOME/platform/vc709/module/"

hotplug_script_name="hotplug.sh"
hotplug_script_path="$driver_path/hotplug_stuff/"

bitload_script_name="program_vc709.tcl"
bitload_script_path="$hotplug_script_path"

log_id=$driver_name"|""pci"

# Use first paramter from user, if it's a bit file
bitstream_file="sobel-memloc.bd.bit"
if [ "$#" -ge 1 ] && [[ $1 == *.bit ]] 
then 
	bitstream_file=$1
	echo "Using user given bitstream:" $bitstream_file
else
	echo "Using default bitstream:" $bitstream_file
fi

# Unload the driver if desired by user
if [ "$#" -ge 2 ] && [[ $2 == drv_reload ]] 
then
	sudo rmmod $driver_name
fi

# Program device
if [ "$#" -ge 3 ] && [ $3 == verbose ] 
then 
	vivado -nolog -nojournal -mode tcl -notrace -source $bitload_script_path$bitload_script_name -tclargs $bitstream_file
else
	echo "Programming bitstream silently, this could take while"
	vivado -nolog -nojournal -mode tcl -notrace -source $bitload_script_path$bitload_script_name -tclargs $bitstream_file > /dev/null
	echo "Programming bitstream finished"
fi

# Hotplug pcie-bus
sudo sh $hotplug_script_path$hotplug_script_name
echo "Hotplugging finished"

# Reload driver if desired by user
if [ "$#" -ge 2 ] && [[ $2 == drv_reload || $2 == drv_load ]] 
then
	sudo insmod $driver_path$driver_name".ko"
	sudo chown $calling_user /dev/FFLINK*
fi

# End
# Output last kernel messages regarding fflink and hotplug, if second parameter is verbose
if [ "$#" -ge 3 ] && [ $3 == verbose ] 
then 
	dmesg | tail -7 | grep -iE $log_id
fi
