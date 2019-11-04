if [ -f "tapasco-setup-toolflow.sh" ]; then
    echo "tapasco-setup-toolflow.sh already exists."
else
    echo "Creating tapasco-setup-toolflow.sh"

    export TAPASCO_HOME=/opt/tapasco
    export TAPASCO_HOME_TOOLFLOW=${TAPASCO_HOME}/toolflow
    export TAPASCO_HOME_TCL=${TAPASCO_HOME_TOOLFLOW}/vivado
    export TAPASCO_HOME_RUNTIME=${TAPASCO_HOME}/runtime
    export TAPASCO_WORK_DIR=$PWD

    echo "export TAPASCO_HOME=${TAPASCO_HOME}" > tapasco-setup-toolflow.sh
    echo "echo Using TaPaSCo from ${TAPASCO_HOME}" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_TOOLFLOW=${TAPASCO_HOME}/toolflow" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_TCL=${TAPASCO_HOME_TOOLFLOW}/vivado" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_HOME_RUNTIME=${TAPASCO_HOME}/runtime" >> tapasco-setup-toolflow.sh
    echo "export TAPASCO_WORK_DIR=$PWD" >> tapasco-setup-toolflow.sh

    echo "export PATH=\"${TAPASCO_HOME_TOOLFLOW}/bin:${TAPASCO_HOME_RUNTIME}/bin:${TAPASCO_WORK_DIR}/build/install/usr/local/bin/:${TAPASCO_HOME_TOOLFLOW}/scala/build/install/tapasco/bin:\$PATH\"" >> tapasco-setup-toolflow.sh
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
