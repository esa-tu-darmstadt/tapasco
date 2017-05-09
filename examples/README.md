# ThreadpoolComposer Examples
## Building the examples 
This directory contains *TPC API* example programs for each of the trivial
kernels contained in the initial release of *ThreadpoolComposer*. Each sub-
directory contains a Makefile, you can build all variants automatically using

```
make
```

This should build each example in three variants:
* <KERNEL>-example
  Single-threaded execution of test runs.
* <KERNEL>-example-mt
  Multi-threaded execution of test runs based on Pthreads.
* <KERNEL>-example-mt-ff
  Multi-threaded execution of test runs based on FastFlow ff_farm; number of
  workers will correspond to value of sysconf(_SC_NPROCESSORS_CONF).

For the FastFlow-variant it is necessary to point the `FF_ROOT` environment to
the installation directory of FastFlow. It was tested against REPARA FastFlow
v2.0.6 (as delivered in D6.1).

## Composing a suitable hardware threadpool
With the exception of `memcheck`, which does not require any specific kernel to
be instantiated in the composition, all other examples provide a configuration
file `<KERNEL>.cfg` in their respective directory which can be used to compose
a hardware threadpool with 48 instances of the kernel:

```
cd $TPC_HOME && TPC_MODE=sim TPC_FREQ=250 sbt "compose configFile ..."
```

## Running the examples
The examples can be run against a virtual FPGA provided by simulation, see the
ThreadpoolComposer documentation for more details.
Every example will output some information about correctness of each run, and
will conclude with either `SUCCESS!` or `FAILURE`. Verbose debug output for the
underlying *TPC API* and *Platform API* implementations can be activated using
the `source $TPC_HOME/sim_setup.sh`.

Note: Example programs must currently be run in the same directory as simulation.

