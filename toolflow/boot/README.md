Scripts to generate BOOT.BIN images for PyNQ, ZedBoard, ZC706, Ultra96, ZCU102
=============================================================
Automates the following steps

  * download specific revision of u-boot-xlnx
  * build it
  * download specific revision of linux-xlnx kernel
  * build uImage
  * create simple Vivado project with default initialization and constraints
  * export .hdf file
  * use hsi to build FSBL
  * use bootgen to generate boot image BOOT.BIN
  * download PyNQ standard SDcard image as base
  * extract root FS from image, and FSBL/SSBL, devicetree for PyNQ
  * prepare SD device to generate bootable SD (optional)

## Usage:

Create a TaPaSCo workspace with the help of `tapasco-init.sh` in the root of this repository and source the generated `tapasco-setup.sh`, this will set `TAPASCO_HOME`. To then generate a boot image simply run: 

```./generate_boot_image.sh BOARD VERSION [DISK SIZE] [DEVICE]```

`VERSION` refers to the release/tag of the Xilinx Open Source Linux [[0]](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/460653138/Xilinx+Open+Source+Linux) stack.

After writing the image to an SDCard and booting up, install Rust and follow the steps in the top level README to build the tapasco runtime. A reboot might be necessary.


## Notes:

  * you might have to add the "noacl" option when mounting the rootfs, depending on distro
  * you can set `OMIT_ROOT=true` to only go through the steps that do not require root privileges, this can be useful for checking just the build processes
