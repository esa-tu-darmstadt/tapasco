NVMulator (Non-Volatile Memory Emulator)
===================
An open-source easy-to-use hardware emulation module that can be seamlessly inserted between the PE of the FPGA processing elements on the FPGA and a conventional DRAM-based memory system. This feature has been proposed in [[Tamimi2023]](#paper) into TaPaSCo.

Table of Contents
-----------------
  1. [Usage](#usage)
  2. [Compatibility](#compatibility)

Usage <a name="usage"/>
-----
To use the NVMulator, please follow the steps outlined below:
 
### Composing a hardware design

```
tapasco compose [arraysum x 1] @ 100MHz -p AU280  --features 'NVMulator {enabled: true}'
```


### API example 
To set the desired latency, please use ```nvMulator(READ_DELAY, WRITE_DELAY, NVM_MODE)``` function call in the API of the TaPaSCo as follow:

```
#define READ_DELAY  100  // in clock cycles
#define WRITE_DELAY 200  // in clock cycles
#define NVM_MODE    1    // enable NVM emulation mode

int main() {
    tapasco::Tapasco tapasco;

    tapasco.nvMulator(READ_DELAY, WRITE_DELAY, NVM_MODE);

    auto job = tapasco.launch(PE_ID, reg1, reg2, ...);
    job();

    return 0;
}
```


Compatibility <a name="compatibility"/>
-------------

NVMulator only supports the Alveo U280 platform that exploits DDR memory. It is not compatible
with PE-local memories and HBM. Compatibility with other TaPaSCo features is not guaranteed.

References
----------
[Tamimi2023] Tamimi, S., Bernhardt, B., Florian, S., Petrov, I., and Koch, A. (2023). NVMulator: A Configurable Open-Source Non-Volatile Memory Emulator for FPGAs. In *Applied Reconfigurable Computing. Architectures, Tools, and Applications (ARC)*.<a name="paper"/>

