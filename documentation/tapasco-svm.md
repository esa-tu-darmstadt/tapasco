TaPaSCo SVM
======================

This feature provides a Shared Virtual Memory (SVM) implementation with physical page
migrations. It is an integration of the framework proposed in [[Kalkhof2021]](#fpt_paper) into TaPaSCo.
It also includes the extension to multi-FPGA systems proposed in [[Kalkhof2022]](#fpl_paper).

Table of Contents
-----------------
  1. [Overview](#overview)
  2. [Usage](#usage)
  3. [Compatibility](#compatibility)

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

For more implementation details and a more detailed evaluation, please refer to [[Kalkhof2021]](#fpt_paper) and
[[Kalkhof2022]](#fpl_paper).

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

If you would like to use multiple FPGAs in parallel, you may want to enable direct device-to-device page migrations
using the following options. Set ```pcie_e2e: true``` to enable PCIe endpoint-to-endpoint transfers between the two
FPGA accelerator cards.

Alternatively, you can use an additional 100G Ethernet link between the FPGA cards. In this case you also need to
specify the QSFP port and MAC address you would like to use for this device, e.g.:

```
tapasco compose [arrayupdate x 1] @ 200 MHz --features 'SVM {enabled: true, network_dma: true, port: 0, mac_addr: 0x00AA11BB22CC}'
```

If none of these two options is active, you can still use SVM on multiple FPGAs, however, the DMA transfers of page
migrations between two devices are then executed in two steps using a bounce buffer in host memory.

### User space API

We kept the changes to the user space API as minimal as possible. So most of your existing TaPaSCo applications will
also run with enabled SVM support. However, keep in mind that the accelerator will use virtual addressing to access
data in memory, regardless of the migration type you are choosing. As long as you do not use pointered data structures
this does not affect your application.

#### ODPMs

If ODPMs should be used to migrated data to FPGA memory, the PE only requires the virtual pointer to the data.
For this purpose, we introduce a new argument type, the ```VirtualAddress<T>``` type. It wraps any pointer type,
but does not need any size information of the input or output data. After checking whether the loaded bitstream
supports SVM, the virtual address of the wrapped pointer is passed directly to the PE. As soon as the
accelerator accesses the passed address, a device page fault is raised and triggers the corresponding ODPMs.

#### UMPMs

There are two ways to initiate UMPMs. The first option is initiating UMPMs explicitly by using ```tapasco.copy_to()```
or ```tapasco.copy_from()``` respectively. Since the memory pages are accessed using the same virtual addresses as
in host software, the ```DeviceAddress``` field of both cores is ignored and may be set to zero. If necessary the
pointer to the migrated data can be passed as ```VirtualAdddress<T>``` to the PE.

The second option is initiating UMPMs implicitly during ```tapasco.launch()```. In this case, simply use the
standard ```WrappedPointer<T>```, optionally as ```InOnly<T>``` or ```OutOnly<T>```, and TaPaSCo will perform
the required migrations prior to starting the PE or after it has finished respectively.
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

Have a look on our [C++](../runtime/examples/C++/svm) and [Rust](../runtime/examples/Rust/libtapasco_svm) code examples
to get more insights on how to use this feature. Both code examples use the ```arrayinit```, ```arrayupdate``` and
```arraysum``` HLS kernels, which are already available in TaPaSCo. The required bitstream can be built with

```
tapasco compose [arrayinit x 1, arrayupdate x 1, arraysum x 1] @ 200 MHz -p AU280 --features 'SVM {enabled: true}
```

Compatibility <a name="compatibility"/>
-------------

### Custom PEs

Since the PE is working with virtual addresses, the minimum address width of the memory AXI interfaces is *47 bit*. 

### Linux kernel <a name="kernel"/>

We use the [Linux HMM API](https://www.kernel.org/doc/html/latest/vm/hmm.html) as OS support
for our page migrations. This requires at least Linux kernel version ```5.10.x```. Also, the 
```CONFIG_DEVICE_PRIVATE``` flag must be enabled during kernel compilation. This may e.g. not
be the case for prebuilt kernels for CentOS 7.

### TaPaSCo features and platforms

SVM support is currently available on the Alveo U50, Alveo U280 and XUPVVH(-ES) platforms. It is not compatible
with PE-local memories and HBM, but uses only DDR memory (HBM is used as standard memory on the Alveo U50).
Compatibility to other TaPaSCo features is not guaranteed.

References
----------
[Kalkhof2021] Kalkhof, T., and Koch, A. (2021). Efficient Physical Page Migrations in Shared Virtual Memory Reconfigurable Computing Systems. In *International Conference on Field-Programmable Technology (FPT)*.<a name="FPT_paper"/>

[Kalkhof2022] Kalkhof, T., and Koch, A. (2022). Direct Device-to-Device Page Migrations in Multi-FPGA Shared Virtual Memory Systems. In *International Conference on Field Programmable Logic (FPL)*.<a name="FPL_paper"/>

