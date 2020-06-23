Features in TaPaSCo
===================

TaPaSCo provides optional features to extend functionality of a composition.

As an example, the following is enabling the FanControl feature for the ZC706
platform.

```
tapasco compose [precision_counter x 1] @ 100 Mhz -p zc706 --features 'FanControl {enabled: true}'
```

## Platform independent features

#### Debug
Add an ILA core to the design. More information in the [debugging documentation](debugging.md).

#### Microblaze
Features related to MicroBlaze PEs.

* `debug`: Attach Microblaze Debug Modules (MDM) to debug ports.

```
microblaze {
  debug: true | false
}
```

## Zynq based platforms

### ZC706

#### FanControl
Reduces the speed of the cooling fan for reduced noise emissions.
```
FanControl {
  enabled: true | false
}
```

### ZCU102

#### SFPPLUS

### Zedboard

#### OLED

### Pynq

#### LED

## PCIe based platforms

#### Cache
Add a Xilinx System Cache to the memory subsystem. Configuration options are:
* Cache size in bytes (default: 32768)
* Associativity (default: 2)
* Overwrite AXI cache signals to always allocate on read / write (force_allocate_read or force_allocate_write, disabled by default)
```
Cache {
  enabled: false | true
  size: 32768 | 65536 | 131072 | 262144 | 524288
  associativity: 2 | 4
  force_allocate_read: false | true
  force_allocate_write: false | true
}
```

### VC709

#### LED

#### ATS-PRI

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The VC709 provides four SFP+ Ports (0 - 3).

### NetFPGA SUME

#### ATS-PRI
See [VC709](#VC709).

### XUP-VVH

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The XUP-VVH provides four QSFP28 Cages. In TaPaSCo each cage provides four physical ports (10GbE each).
So in total you can use up to 16 ports (port numbers 0 - 15) in your design.
The ports 0 - 3 are connected to the top QSFP28 Cage (farthest away from the PCIe connector),
the ports 12 - 15 are connected to the bottom QSFP28 Cage (next to the PCIe connector)

#### HBM
Allows to connect a subset of the AXI master interfaces of PEs to HBM memory instead of DDR. Each AXI master will be connected to its individual memory block (-> no data sharing possible) of size 256 MB. Up to 32 AXI masters can be connected to HBM. This is configured by specifying "groups" consisting of a PE-ID, a count and one or multiple interface names.

```
HBM {
  "HBM0": {
  	"ID": "PE1",
  	"Count": "2",
  	"Interfaces": "M_AXI"
  },
  "HBM1": {
  	"ID:"PE2",
  	"Count": "1",
  	"Interfaces": "M_AXI M_AXI_2"
  }
}
```

This example connects the M_AXI interface of two PE1 instances and the M_AXI and M_AXI_2 interfaces of one PE2 instance to HBM. All other AXI masters are connected to DDR.

#### Regslice
Allows to enable or disable the optional AXI register slices. The register slices can help to achieve timing closure but introduce latency and may impact performance.

```
Regslice {
  "DMA_HOST": true | false # used by DMA engine to access host memory
  "DMA_MIGIC": false | true # used by DMA engine to access FPGA memory
  "HOST_DMA": true | false # used to program DMA engine
  "HOST_MEMCTRL": true | false # used to configure and query ECC
  "HOST_ARCH": true | false # used to configure & start PEs
  "ARCH_MEM": false | true # used by architecture for memory access; between interconnect network and memory
  "PE": false | true # used by PEs for memory access; between PE and interconnect network (only for non HBM-memory)
  "HBM_PE": false | true # used by PEs for memory access; between PE and smartconnect (only for HBM-memory)
  "HBM_HBM": false | true # used by PEs for memory access; between smartconnect and HBM (only for HBM-memory)
}
```
If no value is given for a register slice (or for all), a default value is used. The default value for each register slice is the first value in the example above.
