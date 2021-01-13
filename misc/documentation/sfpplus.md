SFPPLUS in TaPaSCo
===================

A number of platforms in TaPaSCo provide the SFP+-feature which allows to send/recieve network packets.
The following will describe the general configuration format.
The information, which platforms are supported, as well as platform specific information (like the number of available SPF+ Ports),
can be found [here](tapasco-features.md).

## Configuration format

The configuration format is split into three parts:
 1. The [Port Definition](#port-definition)
 2. The [Connections of PEs](#pe-connections) to ports
 3. (Optional) The [Mode](#mode) if the platform supports multiple modes


### Port Definition

Here you can specify a list of ports. Each port has four properties:
 - The name of the port: Used to reference the port when specifiying the connections
 - The mode of the port: How PEs are connected to the port ([singular](#singular-mode), [roundrobin](#roundrobin-mode), [broadcast](#broadcast-mode))
 - The physical port number: Depends on the platform, see [TaPaSCo Features](tapasco-features.md)
 - Where the clock synchronization should occur: Either the synchronization is done via AXI-Stream interconnects (`ic_sync: true`).
   Alternatively the synchronization can be handled by the PE (`ic_sync: false`). In the latter case the PE must have a separate
   clock/reset-pair for each AXI-Stream interface.

Example:

```
SFPPLUS {
  "Ports": [
    {
  	  "name": "port_A",
  	  "mode": "singular",
  	  "physical_port": "0",
  	  "ic_sync": false
  	},
  	{
  	  "name": "port_B",
  	  "mode": "roundrobin",
  	  "physical_port": "1",
  	  "ic_sync": true
  	}
  ],
  ...
}
```

#### Singular Mode

In this mode each Port can only have one sending AXIS-Interface and one recieving AXIS-Interface connected. They are directly connected to the port.

#### Roundrobin Mode

In this mode the packets recieved on the port are distributed to all connected AXIS-Interface round-robin: The first recieved packet is forwarded
to the first AXIS-Interface, the second packet to the second AXIS-Interface and so on...

#### Broadcast Mode

In this mode all recieved packets are forwarded to all connected AXIS-Interfaces.

### PE Connections

Here you first define groups of PEs and then for each group how their AXIS-Interfaces are mapped to the ports.
A group of PE is defined by the ID of the PE-Type and a number. Each PE in your composition may only be used
in one of these groups. Each group defines mappings from their AXIS-Interfaces to ports.
A mapping consists of
 - the name of the interface
 - the direction: `rx` for recieving packets and `tx` for sending packets
 - the port name ([see](#port-definition))

Example:

```
SFPPLUS {
  ...
  "PEs": [
    {
      "ID": "PE1",
      "Count": "1",
      "mappings": [
        {
          "interface": "sfp_axis_0_rx",
          "direction": "rx",
          "port": "port_A"
        },
        {
          "interface": "sfp_axis_0_tx",
          "direction": "tx",
          "port": "port_A"
        }
      ]
    },
    {
      "ID": "PE2",
      "Count": "4",
      "mappings": [
        {
          "interface": "sfp_axis_0_rx",
          "direction": "rx",
          "port": "port_B"
        }
      ]
    }
  ],
  ...
}
```


### Mode

Some platforms provide multiple modes. This can be configured by supplying the name of the mode which should be used.
If no mode is given the default mode for this platform is used.

Example:

```
SFPPLUS {
  ...
  "Mode": "100G"
}
```
