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

#### WrapAXIFull
This determines whether potential AXI4-Full slave ports of the PEs are wrapped (i.e. converted to AXI4-Lite) before connecting them to the interconnect tree. By default this is activated, so all AXI4-Full slave ports are wrapped. This can be deactivated using:

```
WrapAXIFull {
  enabled: false
}
```

#### axi4mmUseSmartconnect
This feature is specific to the axi4mm-architecture. It controls whether AXI interconnects or AXI smartconnects are used for control AND data aggregation in the architecture. By default AXI interconnects are used (except on VERSAL FPGAs). To use AXI smartconnects instead:

```
axi4mmUseSmartconnect {
  enabled: true
}
```


#### CustomConstraints
This feature allows to include a custom constraints file (xdc).

```
CustomConstraints {
  path: "/path/to/file.xdc" # this needs to be an absolute path
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

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The ZC706 provides one Mode (10G) with one SFP+ Ports (0).

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
The VC709 provides one Mode (10G) with four SFP+ Ports (0 - 3).

### NetFPGA SUME

#### ATS-PRI
See [VC709](#VC709).

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The VC709 provides four SFP+ Ports (0 - 3).

### XUP-VVH

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The XUP-VVH provides four QSFP28 Cages.
There are two modes:
 - In the default mode (10G) each cage provides four physical ports (10GbE each). So in total you can use up to 16 ports (port numbers 0 - 15) in your design. The ports 0 - 3 are connected to the top QSFP28 Cage (farthest away from the PCIe connector), the ports 12 - 15 are connected to the bottom QSFP28 Cage (next to the PCIe connector).
 - In 100G mode there four physical ports (100GbE each). Port 0 is the top QSFP28 Cage, Port 3 is the bottom QSFP28 Cage.

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

#### SVM

The Shared Virtual Memory (SVM) extensions is documented [here](tapasco-svm.md).

### Alveo U50/U280

#### SFPPLUS
The configuration for this feature can be found [here](sfpplus.md)
The Alveo U50/U280 provide(s) one/two SFP+ Ports (0 - 1).

#### SVM

The Shared Virtual Memory (SVM) extensions is documented [here](tapasco-svm.md).

### Versal

#### AI Engine

```
AI-Engine {
  "freq": -1 | <MHz>, # Frequency of the AI engine
  "adf": /path/to/libadf.a,
  <AIE stream name>: <PE interface name> # supports wildcard matching for PE interface
}
```

If no explicit stream connections are given in the plugin options, the plugin tries to match streams according to direction and datawidth. Please check the log file for the actual result. **Note**: Only Vivado 2023.1 and newer is supported for Versal AI Engines.

#### DMA Streaming

The DMA streaming feature allows to directly stream data from the DMA engine into the user PE, and the other way round. The user PE may provide standard AXI4 stream interfaces. The interface connections are specified in the feature properties as follows:

```
DMA-Streaming {
  "master_port": <port_name>,
  "slave_port": <port_name>
}
```

In host software, use the ```makeInputStream()``` and ```makeOutputStream()``` wrapper of the C++ API, or the ```DataTransferStream``` parameter in Rust.

**Note**: Currently the feature only supports one input and one output stream.
