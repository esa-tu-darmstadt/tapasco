# SVM Example

This example demonstrates the usage of the Shared Virtual Memory (SVM) feature of TaPaSCo.
Checkout the [feature documentation](../../../../documentation/tapasco-svm.md) for more
information.

## Building the example

Normally, the example is built automatically with the ```tapasco-build-libs``` command
and can be found in the ```build ``` directory in your workspace. You can also build it with

```sh
mkdir build && cd build && cmake .. && make
```

Either way make sure that you compile the runtime with the SVM flag

```sh
tapasco-build-libs --enable_svm
```

## Preparing a hardware design

The example contains four test. One for the HLS example kernels ```arraysum```, ```arraysum```
and ```arraysum``` each, and an additional testcase using all three kernels in a pipeline.
The program detects automatically which kernels are available and executes the corresponding tests.
You can create a hardware design containing one of the kernels e.g. with

```sh
tapasco compose [arrayupdate x 1] @ 200 MHz -p AU280 --features 'SVM {enabled: true}'
```

Or with all three kernels:

```sh
tapasco compose [arrayinit x 1, arraysum x 1, arrayupdate x 1] @ 200 MHz -p AU280 --features 'SVM {enabled: true}'
```

