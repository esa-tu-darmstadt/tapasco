#!/usr/bin/python
import sys
import subprocess

clean = len(sys.argv) > 1 and sys.argv[1] == "clean"
debug = len(sys.argv) > 1 and (sys.argv[1] == "debug" or sys.argv[1] == "driver_debug")
driver_debug = len(sys.argv) > 1 and sys.argv[1] == "driver_debug"

moddir = "$TAPASCO_HOME/platform/zynq/module"
pdir = "$TAPASCO_HOME/platform/zynq/build"
adir = "$TAPASCO_HOME/arch/axi4mm/build"

if clean:
	subprocess.call(["rm -rf " + pdir], shell=True)
	subprocess.call(["rm -rf " + adir], shell=True)
	subprocess.call(["cd " + moddir + " && make clean"], shell=True)
else:
	if debug:
	    print("Building debug mode libraries...")
	else:
	    print("Building release mode libraries, pass 'debug' as first argument to build debug libs...")
	
	subprocess.call(["cd " + moddir + " && make " + ("" if driver_debug else "release ")], shell=True)
	subprocess.call(["mkdir -p " + pdir + " && cd " + pdir + " && cmake " + ("" if debug else "-DCMAKE_BUILD_TYPE=Release") + " .. && make && make install"], shell=True)
	subprocess.call(["mkdir -p " + adir + " && cd " + adir + " && cmake " + ("" if debug else "-DCMAKE_BUILD_TYPE=Release") + " .. && make && make install"], shell=True)
