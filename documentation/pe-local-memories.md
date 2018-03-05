PE-local memories
=================

As of version 2018.1, TaPaSCo supports _PE-local memories_, e.g., scratchpad
memories like BRAM and similar, which are only accessible to their corresponding
processing element and the host. This support required several additional
changes, e.g., the scheduler had to be extended to execute "just-in-time"
transfers for jobs, because the scheduled PE must be known prior to the
transfers. This document sheds some light on the basic ideas behind the
implementation.

General Approach: Hardware
--------------------------

To notify TaPaSCo of available local memories, the PE has to implement
additional AXI4 slave interfaces, which are marked for "memory" use (as opposed
to "register" use for control registers). TaPaSCo 2018.1+ will map the PE into
the global address space by first mapping all "register" slaves, followed by the
memory slaves, in alphabetic order of the interface names. This ordering
guarantees that each memory slot is associated with the PE before it and makes
it simple to iterate over the local memories of a PE. Each slave will be
assigned to its own _virtual slot_ in the Architecture, i.e., one of currently
128 fixed 64KiB address slots, and will be addressable from the host there.

Information about the size of the memories (and their presence) is stored in the
TaPaSCo status core, which has been extended with additional registers to store
size of memory (if any). Whenever this register is set to a value > 0, it is
assumed that the slave interface does _not_ control a PE. This should also be
visible in the kernel map in `tapasco_debug`.

Note that this means that local memories are in the **control address space**,
and are usually not addressable from within the design, e.g., by DMA engines.
Since these memories are very small, data transfers are done via the CPU; On the
Zynq platforms the memory area is `mmap`'ed into user space and can be accessed
quite efficiently. 

General Approach: Software
--------------------------

On the software side of things, the intention is to make local memories "look"
as normal as possible. Meaning: As far as possible, the existing data transfers
are only extended by new flags for pe-local transfers. However, since the target
address for the transfers depends on the scheduler PE decision, it was necessary
to implement a delayed transfer mechanism on job-level:

`tapasco_device_job_set_arg_transfer` is a new API function that attaches a
future transfer to a job. The transfer itself will be executed by the scheduler
before the launch of the job on the selected PE. It will also automatically
replace the given argument value passed to the PE to the value returned from
memory allocator, so that the address is valid within the PE (see below for
limitations and details on the memory allocation).

Note that this API function is not limited to pe-local memories, but can also be
used to trigger regular transfers in the same way.

Local Address Spaces and Memory Allocation
------------------------------------------

Each memory slave at a PE has its own address space and requires a separate
memory allocator to control addresses within. To avoid having to explicitly
define the internal address layouts of PEs, some assumptions are made:

  1.  The first memory slave starts at address 0x0 in PE-local memory.

  2.  Each subsequent memory slave is contiguous with the first; e.g., if
      the first slave is 0x1000 bytes, it will occupy 0x0000 - 0x0FFF. A second
      slave of 0x10000 bytes would then occupy 0x01000 - 0x11000, and so on.

  3.  The memory slaves support random access read and writes, i.e., it is
      expected behavior that memory can be written and verified by reading in
      any order of accesses.

If the automatic address mapping does not match with the internal address space
of the PE, you must fix the addresses computed by TaPaSCo manually in the PE
code (should be simple, probably only fixed offsets).

Each address space is controlled by a local memory allocator, which is
initialized during start. TaPaSCo uses a buddy allocator for devices with
PE-global on-board memories, but the implementation is way to heavy for small
memories. Instead, an ultra-primitive first-fit algorithm for address management
is implemented in `common/src/gen_mem.c` and used by
`arch/common/src/tapasco_memory.c`.

Regular calls to `tapasco_device_alloc` support the local memory flags (see
[`arch/common/include/tapasco.h`](arch/common/include/tapasco.h)) by switching
to local variants, which use the memory allocators internally. It should be
hidden from the outside world, except that the returned `tapasco_handle_t`
contains local addresses instead of global ones.

Programming with local memories
-------------------------------

TaPaSCo API programming should not change much, as explained above. Simply
replace the manual allocations with calls to `tapasco_device_job_set_transfer`
and launch the jobs as usual. Since this is an early version, I'd suggest
building and running with maximal debug output at first, i.e., at least


```
tapasco-build-libs --mode debug
export LIBTAPASCO_DEBUG=-1
export LIBPLATFORM_DEBUG=-1
export LIBTAPASCO_LOGFILE=libtapasco.log
export LIBPLATFORM_LOGFILE=libplatform.log
```

This should generate the logfiles `libtapasco.log` and `libplatform.log` resp.
at the location of the execution.

Limitations
-----------

  0.  This is an **alpha version**, a.k.a. hardhat area! I expect bugs, and so
      should you.

  1.  Due to the fixed address layout, local memories currently cannot exceed
      64KiB of addressable space (will be fixed with free layout later).

  2.  PCIe devices perform single-word writes to control space to transfer data
      to local memories. This is extremely inefficient and should best be fixed
      by implementing an `mmap` approach for register space, if possible.

  3.  `tapasco_debug` does not yet  provide some more information, e.g., size
      and addresses of all memory slots, that would be helpful.

  4.  `tapasco_device_job_set_arg_transfer` does not yet support one-way
      transfers (like `const` values in the C++ API). This means that the local
      data will be copied back on each call, which is useless in many cases.
      Possible fix: add flags to the call to indicate one-ways.

  5.  The memory allocator algorithm is not particularly efficient, and does not
      support compaction, or other advanced features. If this proves to be a
      problem, it may need to be fixed.

  6.  Current implementation of delayed transfers is inefficient: the scheduler
      blocks other executions while waiting on data transfers. Should probably
      be done in a separate data transfer thread. If the async launches feature
      is ever implemented, the new architecture should take this into account.

  7.  The C++ API does not support delayed transfers yet, use the C API.

  8.  Explanatory example code is missing.
