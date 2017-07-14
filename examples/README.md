# Tapasco Examples
## Building the examples
This directory contains *TaPaSCo API* example programs for each of the trivial
kernels contained in the initial release of **Tapasco**. Each subdirectory
contains a build file for [CMake][1] to generate the build files. You can simply
build the examples out-of-tree by moving to its directory and running

```sh
mkdir build && cd build && cmake .. && make
```

If you would like to compile with release settings, use

```sh
mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make
```

This should build each example in two variants:
*   `<KERNEL>-example`
    Single-threaded execution of test runs.
*   `<KERNEL>-example-mt`
    Multi-threaded execution of test runs based on Pthreads.

## Building all examples at once
If you'd rather build all examples at once, there is a `CMakeLists.txt` that
gathers all subprojects in a single build. To use it, run

```sh
mkdir -p build && cd build && cmake .. && make
```
Or, for release mode build:
```sh
mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make
```
**NOTE** This does not build `libtapasco` and `libplatform` in debug mode! Use
`tapasco-build-libs` for rebuilding the libraries.

## Composing a suitable hardware threadpool
With the exception of `memcheck`, which does not require any specific kernel to
be instantiated in the composition, all examples require a suitable bitstream
for the FPGA with at least one instance of the kernel used in the example.
Some time measurements may depend on a *fixed design frequency of 100 MHz*.
For testing purposes, build the bitstreams with that frequency, e.g.,
```sh
tapasco compose [arrayupdate x 1] @ 100 MHz --platforms vc709
```

## Running the examples
The examples can usually be run without inputs, but check the outputs of each
program for errors. Every example will output some information about correctness
of each run, and will conclude with either `SUCCESS!` or `FAILURE`.

## Debugging and Troubleshooting
Verbose debug output for the underlying *Tapasco API* and *Platform API* implementations can be activated using the *debug mode libraries*,  which can be
build via
```sh
tapasco-build-libs --mode debug --rebuild
```
The output can be controlled using two environment variables, `LIBTAPASCO_DEBUG`
and `LIBPLATFORM_DEBUG`. Each controls a 32bit bitfield, where each bit
enables/disables logging of a specific part of the library. By default, logging
is to `stdout` and `stderr`. You can redirect into logfiles by setting
`LIBTAPASCO_LOGFILE` and `LIBPLATFORM_LOGFILE`.

Example for running a program with full logging:
```
LIBTAPASCO_DEBUG=-1 LIBTAPASCO_LOGFILE=libtapasco.log LIBPLATFORM_DEBUG=-1 \
LIBPLATFORM_LOGFILE=libplatform.log <PROGRAM> ...
```
For convenience you can also set the environment variables for the current shell:
```sh
export LIBTAPASCO_DEBUG=-1
export LIBTAPASCO_LOGFILE=libtapasco.log
export LIBPLATFORM_DEBUG=-1
export LIBPLATFORM_LOGFILE=libplatform.log
```
All programs run in the same shell will automatically use these values.

Please note that the debug libraries *should never be used for performance
measurements*! The logging is carefully designed to minimize the overhead, but
the overhead compared to the release builds is significant, nevertheless.

[1]: https://cmake.org/
