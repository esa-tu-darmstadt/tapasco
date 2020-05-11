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

if [ -f "tapasco-setup-toolflow.sh" ]; then
    echo "tapasco-setup-toolflow.sh already exists."
else
    echo "Creating tapasco-setup-toolflow.sh"

    export TAPASCO_HOME=/opt/tapasco
    export TAPASCO_HOME_TOOLFLOW=${TAPASCO_HOME}
    export TAPASCO_HOME_TCL=${TAPASCO_HOME_TOOLFLOW}/vivado
    export TAPASCO_HOME_RUNTIME=${TAPASCO_HOME}/runtime
    export TAPASCO_WORK_DIR=$PWD

    echo "export TAPASCO_HOME=${TAPASCO_HOME}" > tapasco-setup-toolflow.sh
    echo "echo Using TaPaSCo from ${TAPASCO_HOME}" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_TOOLFLOW=${TAPASCO_HOME}" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_TCL=${TAPASCO_HOME_TOOLFLOW}/vivado" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_RUNTIME=${TAPASCO_HOME}/runtime" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_WORK_DIR=$PWD" >> tapasco-setup-toolflow.sh

    echo "export PATH=\"${TAPASCO_HOME_TOOLFLOW}/bin:\$PATH\"" >> tapasco-setup-toolflow.sh
    echo "export MANPATH=\$MANPATH:$TAPASCO_HOME/man" >> tapasco-setup-toolflow.sh
    echo "export MYVIVADO=\$MYVIVADO:${TAPASCO_HOME_TCL}/common" >> tapasco-setup-toolflow.sh
    echo "export XILINX_PATH=\$XILINX_PATH:${TAPASCO_HOME_TCL}/common" >> tapasco-setup-toolflow.sh

    chmod +x tapasco-setup-toolflow.sh

    echo "Creating TaPaSCo folder structure"
    mkdir -p core
    mkdir -p kernel

    echo "Fetching example cores"
    for d in `ls ${TAPASCO_HOME_TOOLFLOW}/examples/kernel-examples/`; do
        if [ ! -d "kernel/$d" ]; then
            echo "Fetched $d"
            ln -s ${TAPASCO_HOME_TOOLFLOW}/examples/kernel-examples/$d kernel/$d
        fi
    done
fi
