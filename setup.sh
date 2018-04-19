if which locate > /dev/null 2>&1; then
  LIBMPFR=`locate libmpfr | grep '\.so\.' | sort -nr | head -1`
else
  LIBMPFR=`find /usr -name 'libmpfr*so*' 2>/dev/null | sort -nr | head -1`
fi

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
echo "TAPASCO_HOME=$TAPASCO_HOME"
export PATH=$TAPASCO_HOME/bin:$PATH
export MANPATH=$MANPATH:$TAPASCO_HOME/man
export MYVIVADO=$MYVIVADO:$TAPASCO_HOME/common
export XILINX_PATH=$XILINX_PATH:$TAPASCO_HOME/common
if [[ -n $LIBMPFR ]]; then
	echo "LD_PRELOAD=$LIBMPFR"
else
	echo "WARNING: awk in modern Linux is incompatible with Vivado's old libmpfr.so" >&2
	echo "This can be fixed by pre-loading a new libmpfr.so, but none was found in /usr/lib." >&2
	echo "If you run into problems (awk: symbols not found), please install libmpfr."
fi
