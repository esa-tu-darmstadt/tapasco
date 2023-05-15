#!/bin/python
# Copyright (c) 2014-2023 Embedded Systems and Applications, TU Darmstadt.
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

import argparse
import errno
import os
from os import path
import signal
import sys
from time import sleep
import shutil
import subprocess

sim_dir = f"{os.environ['TAPASCO_WORK_DIR']}/simulation"

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

    def _add_end(string):
        return string + bcolors.ENDC

    def h(string):
        return bcolors._add_end(bcolors.HEADER + string)
    def bl(string):
        return bcolors._add_end(bcolors.OKBLUE + string)
    def c(string):
        return bcolors._add_end(bcolors.OKCYAN + string)
    def g(string):
        return bcolors._add_end(bcolors.OKGREEN + string)
    def w(string):
        return bcolors._add_end(bcolors.WARNING + string)
    def f(string):
        return bcolors._add_end(bcolors.FAIL + string)
    def b(string):
        return bcolors._add_end(bcolors.BOLD + string)
    def u(string):
        return bcolors._add_end(bcolors.UNDERLINE + string)


def handler(sig, frame):
    global make_vivado_prj
    if make_vivado_prj is not None and make_vivado_prj.returncode is None:
        grp = os.getpgid(make_vivado_prj.pid)
        os.killpg(grp, signal.SIGTERM)

    global make
    if make is not None and make.returncode is None:
        grp = os.getpgid(make.pid)
        os.killpg(grp, signal.SIGTERM)

    print('')
    sys.exit(0)


def target_vivado_prj(filename, verbose):
    if not path.exists(filename):
        print(bcolors.f(f'File not found: \'{filename}\''))
        sys.exit(-1)

    # copy mif file if exists
    mif_dir = f'{sim_dir}/simulate_testbench.sim/sim_1/behav/questa'
    mif_name = 'system_tapasco_status_base_0.mif'
    if path.exists(f'{mif_dir}/{mif_name}'):
        shutil.copyfile(f'{mif_dir}/{mif_name}', f'{sim_dir}/{mif_name}')

    global make_vivado_prj

    print('Creating Vivado files for simulation')

    make_vivado_prj = subprocess.Popen([shutil.which('make'), '-C', sim_dir, f'SIM_IP={filename}', 'vivado_prj'],
                                       preexec_fn=os.setsid,
                                       stderr=subprocess.STDOUT if verbose == 2 else subprocess.PIPE,
                                       stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE)

    if verbose > 0:
        for line in make_vivado_prj.stdout:
            print(line.decode('utf-8'), end='')

    make_vivado_prj.wait()


def target_make(port, verbose, gui):
    global make

    print('Starting simulation...')

    make = subprocess.Popen([shutil.which('make'), f'SIM_PORT={port}', '-C', sim_dir, 'GUI=1' if gui else 'GUI=0'], preexec_fn=os.setsid,
                            stderr=subprocess.STDOUT if verbose == 2 else subprocess.PIPE,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE)

    simulation_started = False
    for line in make.stdout:
        if verbose > 0:
            print(line.decode('utf-8'), end='')
        if b'[tapasco-message] simulation-started' in line:
            simulation_started = True
            break
    
    if simulation_started == True:
        print(bcolors.g('Simulation started'))
    else:
        print(bcolors.f('Failed to start simulation'))

    if verbose > 0:
        for line in make.stdout:
            print(line.decode('utf-8'), end='')

    make.wait()


def main():
    p = argparse.ArgumentParser(
            prog='tapasco-start-sim',
            description='Start the simulation of the specified TaPaSCo Design'
            )
    p.add_argument('filename', nargs='?', help='Filename of the ZIP Archive containing the TaPaSCo Design. Specify to reload TaPaSCo Design.')
    p.add_argument('--port', default=4040, help='Port number the simulation should listen on for runtime commands.')
    p.add_argument('--verbose', '-v', default=0, help='Display output from questa simulation. Use -v to display STDOUT and -vv to additionally display STDERR', action='count')
    p.add_argument('--gui', help='Run simulation in GUI-mode', action='store_true')
    args = p.parse_args()

    # define global process handles
    global make_vivado_prj
    make_vivado_prj = None

    global make
    make = None

    if args.filename is not None:
        target_vivado_prj(path.abspath(args.filename), args.verbose)

    target_make(args.port, args.verbose, args.gui)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, handler)
    main()

