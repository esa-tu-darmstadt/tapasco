# PDILoader

`pc2.uni-paderborn.de:lennart:PDILoader:1.0`, the core behind the Versal `PDI-Loader` platform feature
(`platform/versal/plugins/pdi_loader.tcl`). A PE asks for the PDI at a memory address on the `PDILoad`
interface; the core hands the request to the PLM (the firmware on the PMC) over an Inter-Processor
Interrupt (IPI) and reports the PLM's verdict. The PLM processes the PDI like at boot.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `IPI_CHANNEL` | 2 | IPI channel 0, 1, 2, 3, 4, or 5 the requests are sent on. IPI6 cannot be used since it has no message buffer, and IPI5 is not recommended as it is the PLM's xsdb master channel, which a JTAG session also uses |
| `TIMEOUT_CYCLES` | 2^30 | clock cycles to wait for the PLM before giving up (error 3); at most 2^31 - 1 |

## The feature

The `PDI-Loader` feature instantiates one `PDILoader` per `PDILoad` master of a PE and connects it to the
`S_AXI_LPD` port of the CIPS (through a SmartConnect when there are several), enables all IPI channels on
the CIPS and checks that every loader reaches its IPI block and the message RAM.

```
PDI-Loader {
  "ipi_channel": <0, 1, 2, 3, 4, or 5>,  # channel of the first loader, default 2; further loaders take the next ones
  "timeout_cycles": <cycles>,            # cycles to wait for the PLM, default 2^30
  "interface": <port_name>,              # only connect PE interfaces matching *<port_name>; default: all
  "ila": "true" | "false"                # AXI ILA on the LPD port (needs the Debug feature)
}
```

IPI5 is also used by xsdb, so avoid it while a JTAG session is open. The PDI must be prepared for the
device with `bootgen` (a partial PDI with the device's IDCODE) and the host must keep it in device memory
until the finish handshake.

## Interfaces

| Port | Description |
|---|---|
| `S_PDI_LOAD` | `PDILoad` slave (`../PDILoad/PDILoad_rtl.xml`), see below |
| `M_AXI_LPD` | AXI4 master, 64-bit address, 32-bit data, single beat, AxPROT = AxCACHE = 0. Connect to the CIPS `S_AXI_LPD` port directly: the IPI message RAM is not reachable over the NoC |
| `aclk`, `aresetn` | clock and active-low reset of both interfaces |

### The PDILoad interface

`pc2.uni-paderborn.de:lennart:PDILoad:1.0`: a start handshake followed by exactly one finish handshake,
both valid/ready:

| Logical port | Direction | Width | Meaning |
|---|---|---|---|
| `START_VALID` / `START_READY` | M / S | 1 | request; the loader is ready while idle and the previous finish was taken |
| `START_ADDR` | M | 64 | physical address of the PDI as the PMC sees it (VCK5000: `0x100_0000_0000` + device address) |
| `FINISH_VALID` / `FINISH_READY` (optional, default 1) | S / M | 1 | the load finished; held until taken |
| `FINISH_ERROR` | S | 8 | 0 = success, otherwise the code below |
| `FINISH_STATUS` (optional) | S | 32 | PLMI status word of the PLM's response (0 = success) |
| `FINISH_LOADER_STATUS` (optional) | S | 32 | XilLoader status word (decode with `xloader.h` of embeddedsw) |

| `FINISH_ERROR` | meaning |
|---|---|
| 1 / 2 | AXI write / read response error: the LPD port is not reachable |
| 3 | timeout, the PLM never acknowledged: usually a channel the PLM is not servicing |
| 4 | the PLM reported a non-zero PLMI status (`FINISH_STATUS`, `FINISH_LOADER_STATUS`) |
| 5 | the channel still holds an unacknowledged earlier request |

A PE gets the interface by naming its ports after the logical names in lower case; the IP packager infers
it when `common/ip` is in the project's `ip_repo_paths`. The prefix is free, the feature finds the
interface by its type (or by name through its `interface` property). A master looks like this:

```systemverilog
module my_pe (
    input  logic        aclk,
    input  logic        aresetn,
    // ... the control slave and the other interfaces of the PE
    output logic        M_PDI_LOAD_start_valid,
    input  logic        M_PDI_LOAD_start_ready,
    output logic [63:0] M_PDI_LOAD_start_addr,           // PLM-visible address of the PDI
    input  logic        M_PDI_LOAD_finish_valid,
    output logic        M_PDI_LOAD_finish_ready,         // optional, 1 when absent
    input  logic [7:0]  M_PDI_LOAD_finish_error,
    input  logic [31:0] M_PDI_LOAD_finish_status,        // optional
    input  logic [31:0] M_PDI_LOAD_finish_loader_status  // optional
);
```

Raise `start_valid` with the address and hold both until `start_ready`; `finish_valid` comes once the
PLM has answered (or the loader gave up) and stays until `finish_ready`.

## The handshake

Every IPI agent on Versal (PMC, PSM, IPI0..6) has a register block with `TRIG`, `OBS`, `ISR`, `IMR`,
`IER` and `IDR`; bit k of each stands for agent k. Writing bit k into an agent's `TRIG` raises an
interrupt at agent k, which sees it as a bit in its own `ISR` and clears it there. `OBS` (observation) is
the read-only mirror on the sender's side: bit k stays set as long as agent k has not cleared the
interrupt. The loader therefore writes the PMC bit (`0x2`) into `IPI<n>.TRIG` and polls `IPI<n>.OBS` until
the PMC bit is clear, which is the PLM's acknowledgement; a PMC bit that is already set before the trigger
means an earlier request on that channel was never acknowledged (error 5). The PLM clears the bit when it
has taken the command, not when the load is finished, which is why the response slot is polled as well.

For channel n the core uses the IPI registers at `0xFF330000 + n * 0x10000` (TRIG +0, OBS +4) and the
message RAM slot `0xFF3F0000 + (2 + n) * 0x200 + 0x40` (request to the PMC) with the response in the same
slot at +0x20. It writes the four request words `{0x030701 (LOAD_SUBSYSTEM_PDI), 0xF (DDR), addr_hi,
addr_lo}`, reads the first word back to prove the RAM is reachable, plants a sentinel in the response
slot, checks that OBS is clear, writes the PMC bit into TRIG, polls OBS until the PLM clears it, then polls
the response slot until the sentinel has been replaced by the PLMI status (the PLM acks before it has
finished the load) and reads the XilLoader status. Every write waits for its response, so the ordering
never depends on the interconnect.

All IPI channels must be enabled on the CIPS (the feature does this): the per-design PLM only scans as
many IPI interrupt bits as there are IPI instances, so a request on a channel beyond that is dropped
silently. We believe this to be a bug in the Versal firmware. 

## Sources

`src/PDILoader.sv` is the core; `component.xml` and `xgui/` were packaged from it with Vivado's
`ipx::package_project` (the `PDILoad` definition must be in the IP repository of the packaging project).
