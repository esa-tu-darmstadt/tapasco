set -e
unset PYTHONHOME
pushd $TAPASCO_HOME_TCL/common/ip/Cascabel/
make clean ip SIM_TYPE=VERILOG
popd

