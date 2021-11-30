TaPaSCo SVM
======================

This feature provides a Shared Virtual Memory (SVM) implementation with physical page
migrations. It is an integration of the framework proposed in [[Kalkhof2021]](#paper) into TaPaSCo.

Table of Contents
-----------------
  1. [Overview](#overview)
  2. [Usage](#usage)
  3. [Compatibility](#compatibilty)

Overview <a name="overview"/>
--------

The basic idea of SVM is to extend the virtual address space of the user application to
the accelerator running on the FPGA. This allows seamless passing of pointers between
software and hardware, since the accelerator operates on virtual addresses as well.
It is especially beneficial when working on complex pointer-based data structures as
no pointer relocations are required, and it may prevent copying the entire data
structure to device memory although the accelerator only uses a subset.

Our SVM implementation uses physical page migrations. If the hardware accelerator tries
to access data in memory, the required memory pages are moved from host to device
memory. This allows very efficient memory accesses once the pages are present in
device memory. The translation from virtual to physical addresses is handled by an
on-FPGA IOMMU using TLBs.

We provide two different types of page migrations:
  - On-Demand Page Migrations (ODPMs)
  - User-Managed Page Migrations (UMPMs)

ODPMs are initiated by a page fault. This may be a device page fault if a TLB miss
occurs in the on-FPGA IOMMU, or a CPU page fault if the user program tries to access
a memory page which is currently located in device memory. ODPMs are handled completely
automatically by the driver and require no intervention by the user.

UMPMs are initiated by the user software. The user specifies a virtual memory region
which should be moved to or from device memory, and the driver migrates all required
memory pages together. This reduces overhead during the migration and may improve the
overall performance.

For more implementation details and a more detailed evaluation, please refer to [[Kalkhof2021]](#paper).

Usage <a name="usage"/>
-----

### Compiling the runtime

The SVM feature must be enabled explicitly in the TLKM. The overall
compilation steps stay the same, however, use the following additional flag while
compiling the runtime:

```
tapasco-build-libs --enable_svm
```

Please check whether your Linux kernel fulfills the [requirements](#kernel) if the compilation should not succeed.

### Composing a hardware design

Creating a hardware design with the SVM feature enabled is as simple as creating a
conventional design with TaPaSCo. Just add the feature to your command or your
composition file:

```
tapasco compose [arraysum x 1] @ 200 MHz --features 'SVM {enabled: true}'
```

### User space API

We kept the changes to the user space API as minimal as possible. So most of your existing TaPaSCo applications will
also run with enabled SVM support. However, we introduce a new argument type, the ```VirtualAddress<T>``` type.
It wraps any pointer type, but does not need any size information. After checking whether the loaded bitstream
supports SVM, the virtual address of the wrapped pointer is passed directly to the PE. As soon as the
accelerator accesses the address, a device page fault is raised and triggers the corresponding ODPMs. 
If you would like to use UMPMs instead, simply use the standard ```WrappedPointer<T>```,
optionally as ```InOnly<T>``` or ```OutOnly<T>```, and TaPaSCo will perform the required migrations.
In Rust use the ```DataTransferAlloc``` parameter for UMPMs, where you can also specify whether the
UMPMs should be executed to and/or from device memory. Note that in Rust ```pe.release()``` will return 
*all* buffers passed as ```DataTransferAlloc``` to ```pe.start()```, no matter whether the ```from_device``` 
parameter has been set to ```true``` or ```false```. This way the user program can regain ownership after the 
PE has finished its execution. 

#### ODPMs vs. UMPMs

In comparison to the conventional DMA copy-based memory management scheme which TaPaSCo uses originally,
the SVM feature introduces additional overhead during the data migration process due to various reasons.
This is especially the case for ODPMs, since the pages are migrated in small bundles only, or even
one by one. UMPMs may decrease the migration overhead already significantly, as they allow to migrate 
many pages together. On the other hand, ODPMs allow overlapping of computation and data migration.
The following hints may help you with your decision which migration type matches your application best:

  - ODPMs
    - Moderate data throughput (benefit from overlapping computation and data migration)
    - Unknown size of array or data structure
    - Not known in advance which data is eventually required by the accelerator
  - UMPMs
    - High data throuput (accelerator would stall while waiting for ODPMs)
    - Size of array or data structure, and required data well-known in advance
    
Note that arrays are always allocated in host memory first, and need to be migrated to device memory
when using SVM. Hence, a UMPM to device memory may be beneficial in scenarios where you would omit
it by using ```OutOnly<T>``` normally. Furthermore, the migration of an uninitialized array is much
more efficient since the device memory only needs to be cleared instead of copying the memory pages 
from host to device.

Have a look on our [C++](../runtime/examples/C++/svm) and [Rust](../runtime/examples/Rust/libtapasco_svm) code examples to get more insights on how to use this feature.

Compatibility <a name="compatibility"/>
-------------

### Linux kernel <a name="kernel"/>

We use the [Linux HMM API](https://www.kernel.org/doc/html/latest/vm/hmm.html) as OS support
for our page migrations. This requires at least Linux kernel version ```5.10.x```. Also, the 
```CONFIG_DEVICE_PRIVATE``` flag must be enabled during kernel compilation. This may e.g. not
be the case for prebuilt kernels for CentOS 7.

### TaPaSCo features and platforms

SVM support is currently only available on the Alveo U280 platform. It is not compatible
with PE-local memories and HBM, but uses only DDR memory. Compatibility to other TaPaSCo
features is not guaranteed.

References
----------
[Kalkhof2021] Kalkhof, T., and Koch, A. (2021). Efficient Physical Page Migrations in Shared Virtual Memory Reconfigurable Computing Systems. In *International Conference on Field-Programmable Technology (FPT)*.<a name="paper"/>

