export TAPASCO_HOME=$PWD
export PATH=$TAPASCO_HOME/bin:$PATH
export MANPATH=$MANPATH:$TAPASCO_HOME/man
# source ~/vivado_15.sh
sbt assembly
