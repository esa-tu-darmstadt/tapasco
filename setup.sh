if [[ "-bash" == $0 ]]; then
	export TAPASCO_HOME=`dirname ${BASH_SOURCE[0]} | xargs realpath`
else
	echo "WARNING: non-bash shell; need source setup.sh from the TaPaSCo root dir!"
	export TAPASCO_HOME=$PWD
fi
echo "TAPASCO_HOME=$TAPASCO_HOME"
export PATH=$TAPASCO_HOME/bin:$PATH
export MANPATH=$MANPATH:$TAPASCO_HOME/man
