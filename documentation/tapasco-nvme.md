TaPaSCo NVMe
======================

This extension provides direct access to NVMe-based memory devices, e.g. SSDs, from the FPGA.
It was first introduced in our work *SNAcc* proposed in [[Volz2025]](#h2rc_paper).

Table of Contents
-----------------
  1. [Overview](#overview)
  2. [Composing a Hardware Design](#hwdesign)
  3. [Using the Runtime Plugin](#runtime)
  4. [Example](#example)

Overview <a name="overview"/>
--------

The TaPaSCo NVMe extension provides direct access to NVMe-based memory devices for user PEs.
It relies on PCIe Peer-to-Peer (P2P) transfers, eliminating any host interaction (with the
exception of some initialization at the very beginning of your application).
We have chosen a streaming-based approach matching the architecture of many FPGA-based
accelerators.

### NVMe Streamer IP and Memory Choice for Data Transfers

This extension adds the NVMe Streamer IP as new infrastructure IP to the TaPaSCo hardware design.
The IP manages the entire communication with the NVMe controller. It holds the command submission
and completion queues, generates PRP lists for larger transfers, and notifies the NVMe controller
of new commands using its doorbell registers.

In the NVMe protocol, the data payload is not part of the command itself, but the command contains
pointers to DMA buffers, usually located in main memory. The NVMe controller then fetches data from
or writes  data back to these buffers as stated in the command. In this extensions, we offer three
different options which memory is used for these DMA buffers: internal URAM, FPGA on-bard DRAM or host DRAM.
The following table may serve as quick reference:

Memory        | Discussion
--------------|-----------
Internal URAM | High bandwidth and low latency, however URAM resources are limited and may be required by user PE, bandwidth partially limited by PCIe P2P transfers
On-bard DRAM  | Limits achievable bandwidth, no URAM resources required, but still uses direct PCIe P2P transfers 
Host DRAM     | Requires pinned buffer in host memory, more load on PCIe bus, but highest bandwidth in our evaluation

For more details on the NVMe Streamer IP and an in-depth evaluation refer to [[Volz2025]](#h2rc_paper).

### Interfacing with User PE

User PE and NVMe Streamer IP communicate over four AXI4 Stream buses in total. There is one bus
for commands and one for responses in read and write direction, respectively. We recommend to use
*512 bit* width for the TDATA signals of the read command and response and write command interfaces,
and *8 bit* for the write response interface. Other widths may work but are not tested.

For read transaction from the NVMe device, the user PE issues a data packet with the following
format on the read command channel:

```
[ 63:  0] address on NVMe device (in bytes)
[127: 64] length (in bytes)
[511:128] reserved
```
TLAST signal should be set. The NVMe Streamer IP will then return the read data as continuous stream
on the read response channel.

For write transaction to the NVMe device, the first stream beat contains only the write address in bytes
on the NVMe device. Then all write data is sent over the stream until the end of the transaction is marked
by setting the TLAST signal by the user PE. We ignore the TKEEP signal, all data beats must be properly packed.
Ater the write to the NVMe is fully executed, the NVMe Streamer IP sends one data beat on the write response
bus to mark the transaction as completed.

Composing a Hardware Design <a name="hwdesign"/>
-----

You can either pass the feature options directly to `tapasco compose` on the command line, or use a JSON job file.

First, you need to specify the AXI4 Stream interfaces of your PE which are used for the read and wrte commands and resposnses.
Use the `axis_read_command`, `axis_write_command`, `axis_read_response` and `axis_write_response` options and pass the name
of the respective PE interfaces.

Use the `memory` option to specify which memory should be used to buffer NVMe data transfers. Available values are `"on-board-dram"` for
FPGA on-board DRAM, `"host-dram"` for host memory, and `"uram"` if you want to use URAM.

Optionally, you may set the PCIe address of the NVMe controller using the `ssd_base_address` option. This setting can be overwritten
later using the [runtime plugin](#runtime).

A complete `compose` command could look like this:

```bash
tapasco compose [NvmeTestPE x 1] @ 100 MHz -p AU280 --features 'NVME {axis_read_command: "AXIS_RD_CMD", axis_write_command: "AXIS_WR_CMD", axis_read_response: "AXIS_RD_RSP", axis_write_response: "AXIS_WR_RSP", memory: "uram", ssd_base_address: 0x54000000}'
```

Or the corresponding plugin section in the JSON job file:

```json
{
  "Feature": "NVME",
  "Properties": {
    "enabled": true,
    "axis_read_command": "AXIS_RD_CMD",
    "axis_write_command": "AXIS_WR_CMD",
    "axis_read_response": "AXIS_RD_RSP",
    "axis_write_response": "AXIS_WR_RSP",
    "memory": "uram",
    "ssd_base_address": "0x54000000"
  }
}
```

The NVMe extension is currently supported on the Alveo U280 and Bittware XUPVVH.

Using the Runtime Plugin <a name="runtime"/>
-----

The NVMe extension requires a few initialization steps during runtime. Hence, we provide a runtime plugin and explain
its functionality in the following.

First, retrieve the plugin from the device object using `get_kernel()`:

*Rust:*

```
let nvme = device.get_plugin::<NvmePlugin>();            // immutable reference
let mut nvme_mut = device.get_plugin_mut::<NvmePlugin>(); // mutable reference
```

*C++:*

```
TapascoNvmePlugin nvme = tapasco.get_plugin<TapascoNvmePlugin>();
```

When using C++, be aware that the underlying pointer to the `NvmePlugin` Rust object, which is wrapped by the retrieved
`TapascoNvmePlugin` object, may become invalid as soon as your `Tapasco` object goes out of scope and is destroyed.

In addition to initializing the FPGA part, you also have to setup the NVMe device, e.g. using a custom driver. **This is
not handled by TaPaSCo!** When setting up the I/O queue in the NVMe controller, you require the PCIe adresses of the command
submission and completion queues, which are located in our NVMe Streamer IP. You can retrieve these using the following function
calls. The first element of the returned tuples represents the submission queue PCIe address, and the second element the
completion queue PCIe address, respectively.

*Rust:*
```rust
let [sq_addr, cq_addr] = nvme.get_queue_base_addr()?;
```

*C++:*
```c++
auto [sq_addr, cq_addr] = nvme.get_queue_base_addr();
```

The following table lists all remaining functions offered by our runtime plugin:

Function        | Description
----------------|------------
`is_available()`| Checks whether the currently loaded bitstream includes hardware support for NVMe access
`set_nvme_pcie_addr(u64 addr)` | Pass the PCIe address of the NVMe controller to the NVMe plugin (overwrites address set in hardware composition)
`enable()`      | Enable NVMe plugin and NVMe Streamer IP
`disable()`     | Disable NVMe plugin and NVMe Streamer IP
`is_enabled()`  | Check whether NVMe plugin and NVMe Streamer IP are currently enabled

By default the plugin is disabled after loading the bitstream. Hence, you have to enable it after initialization. When the plugin object is deconstructed,
the NVMe Streamer IP is disabled to prevent unintended traffic on the PCIe bus.

Example <a name="example"/>
-----

We will include a complete example in our [TaPaSCo Examples repository](https://github.com/esa-tu-darmstadt/tapasco-examples).

References
----------
[Volz2025] Volz, D., and Kalkhof, T., and Koch, A. (2025). SNAcc: An Open-Source Framework for Streaming-based Network-to-Storage Accelerators. In *Workshops of the International Conference for High Performance Computing, Networking, Storage and Analysis (SC Workshops ’25)*.<a name="h2rc_paper"/>
