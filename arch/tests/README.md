Debugging and benchmarking tools for TaPaSCo
============================================
Builds `tapasco-benchmark`, which generates a benchmark file for the host, and
`tapasco-debug` which is an interactive debugging tool that can query the
bitstream for functions, peek/poke and monitor registers and IRQ controllers.

Building for benchmarking & debugging
-------------------------------------
Usual out-of-context build with CMake:

`mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release && make && make install`

The last puts the executables in `$TAPASCO_HOME/bin`, which makes them
accessible anywhere after `setup.sh` was sourced.

Building for debugging & dev
----------------------------
`mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Debug && make && make install`

**NOTE: This carries an extreme performance penalty! Make sure you rebuilt in
Release mode before running benchmarks!**
