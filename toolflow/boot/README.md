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
  * you can edit the `OMIT_ROOT` variable in `generate_boot_image.sh` to `OMIT_ROOT=true` to only go through the steps that do not require root privileges, this can be useful for checking just the build processes
  * the ZCU102 seems to be very picky about the SDCard used, sometimes it refuses to load larger files and u-boot simply prints "`mmc fail to send stop cmd`" or similar when loading the `Image` file
    - if that happens, try editing `bootscr/boot-zcu102.txt` to load the compressed image `Image.gz` before re-generating the `boot.scr` script and make sure to copy `Image.gz` from `linux-xlnx/arch/arm64/boot` into the boot section

