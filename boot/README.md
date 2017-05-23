Scripts to generate BOOT.BIN images for PyNQ, ZedBoard, ZC706
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

