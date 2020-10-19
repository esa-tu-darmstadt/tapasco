if [ -n "$BASH_VERSION" ]; then
    command -v xargs > /dev/null || { echo >&2 "ERROR: xargs program not available."; }

    if [ "`uname`" = "Darwin" ]; then
        export TAPASCO_HOME=`dirname ${BASH_SOURCE[0]} | xargs cd | pwd`
    else
        command -v realpath > /dev/null || command -v readlink > /dev/null ||  { echo "ERROR: neither realpath nor readlink programs are available."; }
        command -v xargs > /dev/null && command -v realpath > /dev/null && export TAPASCO_HOME=`dirname ${BASH_SOURCE[0]} | xargs realpath`
        command -v xargs > /dev/null && command -v readlink > /dev/null && export TAPASCO_HOME=`dirname ${BASH_SOURCE[0]} | xargs readlink -f`
    fi
elif [ -n "$ZSH_VERSION" ]; then
    command -v realpath > /dev/null || command -v readlink > /dev/null ||  { echo "ERROR: neither realpath nor readlink programs are available."; }
    command -v xargs > /dev/null && command -v realpath > /dev/null && export TAPASCO_HOME=`dirname ${(%):-%x} | xargs realpath`
    command -v xargs > /dev/null && command -v readlink > /dev/null && export TAPASCO_HOME=`dirname ${(%):-%x} | xargs readlink -f`
else
    echo "WARNING: unknown shell; need to source setup.sh from the TaPaSCo root dir!"
    export TAPASCO_HOME=$PWD
fi
if [ -f "tapasco-setup.sh" ]; then
    echo "tapasco-setup.sh already exists."
else

    echo "Creating tapasco-setup.sh"

    export TAPASCO_HOME=${TAPASCO_HOME}
    export TAPASCO_HOME_TOOLFLOW=${TAPASCO_HOME}/toolflow
    export TAPASCO_HOME_TCL=${TAPASCO_HOME_TOOLFLOW}/vivado
    export TAPASCO_HOME_RUNTIME=${TAPASCO_HOME}/runtime
    export TAPASCO_WORK_DIR=$PWD

    echo "export TAPASCO_HOME=\"${TAPASCO_HOME}\"" > tapasco-setup.sh
    echo "echo Using TaPaSCo from ${TAPASCO_HOME}" >> tapasco-setup.sh
    echo "export TAPASCO_HOME_TOOLFLOW=\"${TAPASCO_HOME}/toolflow\"" >> tapasco-setup.sh
    echo "export TAPASCO_HOME_TCL=\"${TAPASCO_HOME_TOOLFLOW}/vivado\"" >> tapasco-setup.sh
    echo "export TAPASCO_HOME_RUNTIME=\"${TAPASCO_HOME}/runtime\"" >> tapasco-setup.sh
    echo "export TAPASCO_WORK_DIR=\"$PWD\"" >> tapasco-setup.sh

    echo "export PATH=\"${TAPASCO_HOME_TOOLFLOW}/bin:${TAPASCO_HOME_RUNTIME}/bin:${TAPASCO_WORK_DIR}/build/install/usr/local/bin/:${TAPASCO_WORK_DIR}/build/install/usr/local/share/Tapasco/bin:${TAPASCO_HOME_TOOLFLOW}/scala/build/install/tapasco/bin:\$PATH\"" >> tapasco-setup.sh
    echo "export MANPATH=\$MANPATH:$TAPASCO_HOME/man" >> tapasco-setup.sh
    echo "export MYVIVADO=\$MYVIVADO:${TAPASCO_HOME_TCL}/common" >> tapasco-setup.sh
    echo "export XILINX_PATH=\$XILINX_PATH:${TAPASCO_HOME_TCL}/common" >> tapasco-setup.sh

    echo "export Tapasco_DIR=${TAPASCO_WORK_DIR}/build/install/usr/local/share/Tapasco/cmake/" >> tapasco-setup.sh

    echo "if echo \"\${PATH}\" | grep --quiet \"cmake-3.3.2\";" >> tapasco-setup.sh
    echo "then" >> tapasco-setup.sh
    echo "    if ! command -v python3 > /dev/null;" >> tapasco-setup.sh
    echo "    then" >> tapasco-setup.sh
    echo "        echo \"Could not remove old CMake version from Path. Please install python3\"" >> tapasco-setup.sh
    echo "    else" >> tapasco-setup.sh
    echo "        echo \"Removing old CMake version 3.3.2 distributed with Vivado from Path\"" >> tapasco-setup.sh
    echo "        export PATH=\`python3 -c \"import re; print(re.sub(r'[:][^:]*?cmake[-]3[.]3[.]2.*?[:]', ':', '\${PATH}'));\"\`" >> tapasco-setup.sh
    echo "    fi" >> tapasco-setup.sh
    echo "fi" >> tapasco-setup.sh

    chmod +x tapasco-setup.sh

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
