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
Add a Xilinx System Cache to the memory subsystem. Size is configurable and can be forced to overwrite AXI cache signals.
The first entry of the options is the default value.
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

### NetFPGA SUME

#### ATS-PRI
See [VC709](#VC709).
