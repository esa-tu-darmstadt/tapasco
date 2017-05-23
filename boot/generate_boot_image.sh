#!/bin/bash
BOARD=${1:-zedboard}
VERSION=${2:-2016.4}
SDCARD=${3:-}
DIR="$BOARD/$VERSION"
LOGDIR="$DIR/logs"
CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabihf-}
ROOTFS_IMG="$PWD/rootfs.img"
### LOGFILES ###################################################################
BUILD_LINUX_LOG="$PWD/$LOGDIR/build-linux.log"
BUILD_UBOOT_LOG="$PWD/$LOGDIR/build-uboot.log"
BUILD_SSBL_LOG="$PWD/$LOGDIR/build-ssbl.log"
BUILD_UIMAGE_LOG="$PWD/$LOGDIR/build-uimage.log"
BUILD_FSBL_LOG="$PWD/$LOGDIR/build-fsbl.log"
BUILD_BOOTBIN_LOG="$PWD/$LOGDIR/build-bootbin.log"
BUILD_DEVICETREE_LOG="$PWD/$LOGDIR/build-devicetree.log"
PREPARE_SD_LOG="$PWD/$LOGDIR/prepare-sd.log"
EXTRACT_BL_LOG="$PWD/extract-bl.log"
EXTRACT_RFS_LOG="$PWD/extract-rfs.log"
PYNQ_VERSION="pynq_z1_image_2017_02_10"
PYNQ_IMAGE="$PWD/pynq/$PYNQ_VERSION.zip"
PYNQ_IMAGE_URL="https://s3-us-west-2.amazonaws.com/digilent/Products/PYNQ/$PYNQ_VERSION.zip"
# fetch status
FETCH_UBOOT_OK=1
FETCH_LINUX_OK=1
FETCH_PYNQ_IMAGE_OK=1
# build status
BUILD_UBOOT_OK=1
BUILD_LINUX_OK=1
BUILD_UIMAGE_OK=1
PREPARE_SD_OK=1

print_usage () {
	cat << EOF
Usage: ${0##*/} BOARD VERSION [DEVICE]
Build a boot image for the given BOARD and VERSION (git tag). If DEVICE is
given, repartition the device as a bootable SD card (WARNING: all data will
be lost).
	BOARD		one of zc706, zedboard
	VERSION		Vivado Design Suite version, e.g., 2016.4
	DEVICE		SD card device, e.g., /dev/sdb (optional)
EOF
	exit 1
}

check_board () {
	case $BOARD in
		"zedboard")
			;;
		"zc706")
			;;
		"pynq")
			;;
		*)
			echo "unknown board: $BOARD"
			echo "select one of zedboard, zc706 or pynq"
			print_usage
			;;
	esac
}

check_compiler () {
	gcc=`which ${CROSS_COMPILE}gcc`
	if [[ $? -ne 0 ]]; then
		echo "Compiler ${CROSS_COMPILE}gcc not found in path."
		exit 1
	fi
}

check_hsi () {
	hsi=`which hsi`
	if [[ $? -ne 0 ]]; then
		echo "Xilinx hsi tool is not in PATH, please source Vivado settings."
		exit 1
	fi
}

check_vivado () {
	viv=`which vivado`
	if [[ $? -ne 0 ]]; then
		echo "Xilinx Vivado is not in PATH, please source Vivado settings."
		exit 1
	fi
}

check_bootgen () {
	viv=`which bootgen`
	if [[ $? -ne 0 ]]; then
		echo "Xilinx bootgen tool is not in PATH, please source Vivado settings."
		exit 1
	fi
}

check_sdcard () {
	if [[ -n $SDCARD && ! -e $SDCARD ]]; then
	 	echo "SD card device $SDCARD does not exist!"
		exit 1
	fi
}

get_linux () {
	if [[ ! -d $DIR/linux-xlnx ]]; then
		# echo "Fetching linux $VERSION ..."
		mkdir -p "$DIR" > /dev/null &&
		pushd $DIR > /dev/null &&
		if [[ ! -d linux-xlnx ]]; then git clone -b xilinx-v$VERSION --depth 1 https://github.com/xilinx/linux-xlnx > /dev/null; fi &&
		popd > /dev/null
	fi
}

get_u-boot () {
	if [[ ! -d $DIR/u-boot-xlnx ]]; then
		# echo "Fetching u-boot $VERSION ..."
		mkdir -p "$DIR" > /dev/null &&
		pushd $DIR > /dev/null &&
		if [[ ! -d u-boot-xlnx ]]; then git clone -b xilinx-v$VERSION --depth 1 https://github.com/xilinx/u-boot-xlnx > /dev/null; fi &&
		popd > /dev/null
	fi
}

get_pynq_image () {
	if [[ ! -f $PYNQ_IMAGE ]]; then
		# echo "Fetching PyNQ standard image ..."
		mkdir -p `dirname $PYNQ_IMAGE` 2> /dev/null &&
		curl -s $PYNQ_IMAGE_URL -o $PYNQ_IMAGE
	fi
}

extract_pynq_bl () {
	if [[ ! -f $PWD/pynq/BOOT.BIN ]]; then
		pushd $PWD/pynq > $EXTRACT_BL_LOG 2>&1 &&
		IMG=${PYNQ_VERSION}.img
		if [[ -f $IMG ]]; then
			echo "Unzipping $PYNQ_IMAGE to extract $IMG ..." >> $EXTRACT_BL_LOG 2>&1 &&
			unzip -u $PYNQ_IMAGE >> $EXTRACT_BL_LOG 2>&1
		fi &&
		mkdir -p img >> $EXTRACT_BL_LOG  2>&1 &&
		sudo mount -oloop,offset=1M $IMG img >> $EXTRACT_BL_LOG 2>&1 &&
		sudo cp img/BOOT.BIN $VERSION/BOOT.BIN >> $EXTRACT_BL_LOG 2>&1 && 
		sudo chown $USER $VERSION/BOOT.BIN >> $EXTRACT_BL_LOG 2>&1 &&
		sudo cp img/devicetree.dtb $VERSION/devicetree.dtb >> $EXTRACT_BL_LOG 2>&1 &&
		sudo chown $USER $VERSION/devicetree.dtb >> $EXTRACT_BL_LOG 2>&1 &&
		sudo cp img/uEnv.txt ../uenv/uEnv-pynq.txt >> $EXTRACT_BL_LOG 2>&1 &&
		sudo chown $USER ../uenv/uEnv-pynq.txt >> $EXTRACT_BL_LOG 2>&1 &&
		sudo umount img >> $EXTRACT_BL_LOG 2>&1 &&
		rmdir img >> $EXTRACT_BL_LOG 2>&1 &&
		echo "BOOT.BIN and devicetree.dtb are ready in $DIR." >> $EXTRACT_BL_LOG 2>&1
	fi
}

extract_pynq_rootfs () {
	if [[ ! -f $ROOTFS_IMG ]]; then
		IMG=$PWD/pynq/${PYNQ_VERSION}.img
		START=$(fdisk -l $IMG | awk 'END { print $2 }')
		COUNT=$(fdisk -l $IMG | awk 'END { print $4 }')
		echo "Extracting root image from $IMG, start=$START and count = $COUNT" > $EXTRACT_RFS_LOG 2>&1 &&
		dd if=$IMG of=$ROOTFS_IMG skip=$START count=$COUNT >> $EXTRACT_RFS_LOG 2>&1
	fi
}

build_u-boot () {
	if [[ ! -e $DIR/u-boot-xlnx/tools/mkimage ]]; then
		# echo "Building u-boot $VERSION ..."
		case $BOARD in
			"zedboard")
				DEFCONFIG=zynq_zed_defconfig
				;;
			"zc706")
				DEFCONFIG=zynq_zc706_defconfig
				;;
			"pynq")
				DEFCONFIG=zynq_zed_defconfig
				;;
		esac
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG > /dev/null 2>&1 &&
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm tools > $BUILD_UBOOT_LOG 2>&1
	else
		echo "$DIR/u-boot-xlnx/tools/mkimage already exists, skipping." >> $BUILD_UBOOT_LOG
	fi
}

build_linux () {
	if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/Image ]]; then
		# echo "Building linux $VERSION .."
		DEFCONFIG=tapasco_zynq_defconfig
		CONFIGFILE="$PWD/configs/tapasco_zynq_defconfig"
		cp $CONFIGFILE $DIR/linux-xlnx/arch/arm/configs/ &&\
		make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG > /dev/null &&
		make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm -j > $BUILD_LINUX_LOG 2>&1
	else
		echo "$DIR/linux-xlnx/arch/arm/boot/Image already exists, skipping." >> $BUILD_LINUX_LOG
	fi
}

build_ssbl () {
	if [[ ! -e $DIR/u-boot-xlnx/u-boot ]]; then
		# echo "Building second stage boot loader ..."
		DTC=$PWD/$DIR/linux-xlnx/scripts/dtc/dtc
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm DTC=$DTC u-boot > $BUILD_SSBL_LOG 2>&1
	else
		echo "$DIR/u-boot-xlnx/u-boot already exists, skipping." >> $BUILD_SSBL_LOG
	fi
	cp $DIR/u-boot-xlnx/u-boot $DIR/u-boot-xlnx/u-boot.elf >> $BUILD_SSBL_LOG 2>&1
}

build_uimage () {
	if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/uImage ]]; then
	# "Building uImage ..."
	make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm PATH=$PATH:$PWD/$DIR/u-boot-xlnx/tools UIMAGE_LOADADDR=0x8000 uImage > $BUILD_UIMAGE_LOG 2>&1
	else
		echo "$DIR/linux-xlnx/arch/arm/boot/uImage already exists, skipping." >> $BUILD_UIMAGE_LOG
	fi
}

build_fsbl () {
	if [[ ! -f $DIR/fsbl/executable.elf ]]; then
		mkdir -p $DIR/fsbl > /dev/null &&
		pushd $DIR/fsbl > /dev/null &&
		cat > project.tcl << EOF
package require json

set platform_file [open "\$env(TAPASCO_HOME)/platform/$BOARD/platform.json" r]
set json [read \$platform_file]
close \$platform_file
set platform [::json::json2dict \$json]

source "\$env(TAPASCO_HOME)/common/common.tcl"
source "\$env(TAPASCO_HOME)/platform/common/platform.tcl"
source "\$env(TAPASCO_HOME)/platform/$BOARD/$BOARD.tcl"
create_project $BOARD $BOARD -part [dict get \$platform "Part"] -force
set board_part ""
if {[dict exists \$platform "BoardPart"]} {
	set board_part [dict get \$platform "BoardPart"]
	set_property board_part \$board_part [current_project]
}
create_bd_design -quiet "system"
set board_preset {}
if {[dict exists \$platform "BoardPreset"]} {
	set board_preset [dict get \$platform "BoardPreset"]
}
set ps [tapasco::createZynqPS "ps7" \$board_preset 100]
# activate ACP, HP0, HP2 and GP0/1 (+ FCLK1 @10MHz)
set_property -dict [list \
	CONFIG.PCW_USE_M_AXI_GP0 			{1} \
	CONFIG.PCW_USE_M_AXI_GP1 			{1} \
	CONFIG.PCW_USE_S_AXI_HP0 			{1} \
	CONFIG.PCW_USE_S_AXI_HP1 			{0} \
	CONFIG.PCW_USE_S_AXI_HP2 			{1} \
	CONFIG.PCW_USE_S_AXI_HP3 			{0} \
	CONFIG.PCW_USE_S_AXI_ACP 			{1} \
	CONFIG.PCW_USE_S_AXI_GP0 			{0} \
	CONFIG.PCW_USE_S_AXI_GP1 			{0} \
	CONFIG.PCW_S_AXI_HP0_DATA_WIDTH 		{64} \
	CONFIG.PCW_S_AXI_HP2_DATA_WIDTH 		{64} \
	CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL 		{1} \
	CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 		{10} \
	CONFIG.PCW_USE_FABRIC_INTERRUPT 		{1} \
	CONFIG.PCW_IRQ_F2P_INTR 			{1} \
	CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 		{0} \
	CONFIG.PCW_EN_CLK1_PORT 			{1} ] \$ps
if {[tapasco::get_speed_grad] < -1} {
    set_property -dict [list CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {800}] \$ps
}
set clk [lindex [get_bd_pins -of_objects \$ps -filter { TYPE == clk && DIR == O }] 0]
connect_bd_net \$clk [get_bd_pins -of_objects \$ps -filter { TYPE == clk && DIR == I}]
validate_bd_design
save_bd_design
make_wrapper -files [get_files $BOARD/$BOARD.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse $BOARD/$BOARD.srcs/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1
generate_target all [get_files $BOARD/$BOARD.srcs/sources_1/bd/system/system.bd]
write_hwdef -force  -file $BOARD.hdf
puts "HDF in $BOARD.hdf, done."
exit
EOF
		cat > hsi.tcl << EOF
generate_app -hw [open_hw_design $BOARD.hdf] -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir .
EOF
		vivado -nolog -nojournal -notrace -mode batch -source project.tcl > $BUILD_FSBL_LOG 2>&1 &&
		hsi -nolog -nojournal -notrace -mode batch -source hsi.tcl >> $BUILD_FSBL_LOG 2>&1
	else
		echo "$BOARD/fsbl/executable.elf already exists, skipping." >> $BUILD_FSBL_LOG
	fi
}

build_bootbin () {
	# "Building BOOT.BIN ..."
	cat > $DIR/bootimage.bif << EOF
image : {
	[bootloader]fsbl/executable.elf
	u-boot-xlnx/u-boot.elf
}
EOF
	pushd $DIR > /dev/null &&
	bootgen -image bootimage.bif -w on -o BOOT.BIN > $BUILD_BOOTBIN_LOG 2>&1 &&
	popd > /dev/null
}

build_devtree () {
	# "Building devicetree ..."
	case $BOARD in
		"zedboard")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ > $BUILD_DEVICETREE_LOG 2>&1
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ > $BUILD_DEVICETREE_LOG 2>&1
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts 
			;;
		"zc706")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ > $BUILD_DEVICETREE_LOG 2>&1
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ > $BUILD_DEVICETREE_LOG 2>&1
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts 
			;;
	esac
	pushd $DIR > /dev/null &&
	linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o devicetree.dtb devicetree.dts > $BUILD_DEVICETREE_LOG 2>&1 &&
	popd > /dev/null
}

prepare_sd () {
	echo "Erasing first 4GiB of SDcard $SDCARD ..." > $PREPARE_SD_LOG &&
	#sudo dd if=/dev/zero of=$SDCARD bs=1M count=4096 >> $PREPARE_SD_LOG 2>&1 &&
	sudo dd if=/dev/zero of=$SDCARD bs=1024 count=1 >> $PREPARE_SD_LOG 2>&1 &&
	echo "Repartitioning SDcard $SDCARD ..." >> $PREPARE_SD_LOG &&
	sudo sfdisk ${SDCARD} >> $PREPARE_SD_LOG 2>&1 << EOF
2048 204800 c, *
206848 7655424 83 -
EOF
	sudo mkfs.vfat -F 32 -n BOOT ${SDCARD}1 >> $PREPARE_SD_LOG 2>&1
	sudo mkfs.ext4 -F -L root ${SDCARD}2 >> $PREPARE_SD_LOG 2>&1
	copy_files_to_boot &&
	copy_files_to_root
}

copy_files_to_boot () {
	TO=`basename ${SDCARD}1`
	echo "Preparing BOOT partition ..." >> $PREPARE_SD_LOG &&
	mkdir -p $TO >> $PREPARE_SD_LOG 2>&1 &&
	sudo mount ${SDCARD}1 $TO >> $PREPARE_SD_LOG 2>&1 &&
	echo "Copying $DIR/BOOT.BIN to $TO ..." >> $PREPARE_SD_LOG 2>&1 &&
	sudo cp $DIR/BOOT.BIN $TO >> $PREPARE_SD_LOG 2>&1 &&
	echo "Copying $DIR/linux-xlnx/arch/arm/boot/uImage to $TO ..." >> $PREPARE_SD_LOG 2>&1 &&
	sudo cp $DIR/linux-xlnx/arch/arm/boot/uImage $TO >> $PREPARE_SD_LOG 2>&1 &&
	echo "Copying $DIR/devicetree.dtb to $TO ..." >> $PREPARE_SD_LOG 2>&1 &&
	sudo cp $DIR/devicetree.dtb $TO >> $PREPARE_SD_LOG 2>&1 &&
	echo "Copying uenv/uEnv-$BOARD.txt to $TO/uEnv.txt ..." >> $PREPARE_SD_LOG 2>&1 &&
	sudo cp uenv/uEnv-$BOARD.txt $TO/uEnv.txt >> $PREPARE_SD_LOG 2>&1
	sudo umount $TO >> $PREPARE_SD_LOG 2>&1 &&
	rmdir $TO 2> /dev/null &&
	echo "Boot partition ready." >> $PREPARE_SD_LOG
}

copy_files_to_root () {
	TO=`basename ${SDCARD}2`
	echo "dd'ing rootfs onto second partition, this will take a while ..." >> $PREPARE_SD_LOG &&
	sudo dd if=$ROOTFS_IMG of=${SDCARD}2 bs=10M >> $PREPARE_SD_LOG 2>&1
	mkdir -p $TO 2> /dev/null
	sudo mount ${SDCARD}2 $TO >> $PREPARE_SD_LOG 2>&1 >> $PREPARE_SD_LOG 2>&1 &&
	echo "Setting hostname to $BOARD ... " >> $PREPARE_SD_LOG &&
	sudo sh -c "echo $BOARD > $TO/etc/hostname" >> $PREPARE_SD_LOG 2>&1 &&
	#echo "Copying Linux to /linux-xlnx ... " >> $PREPARE_SD_LOG &&
	#sudo sh -c "cp -r $DIR/linux-xlnx $TO/" >> $PREPARE_SD_LOG 2>&1 &&
	echo "Replacing rc.local ... " >> $PREPARE_SD_LOG &&
	sudo sh -c "cp $PWD/misc/rc.local $TO/etc/rc.local" >> $PREPARE_SD_LOG 2>&1 &&
	sudo umount $TO >> $PREPARE_SD_LOG 2>&1 &&
	rmdir $TO 2> /dev/null &&
	echo "RootFS partition ready." >> $PREPARE_SD_LOG
}

################################################################################
################################################################################
echo "Cross compiler ABI is set to $CROSS_COMPILE."
echo "Board is $BOARD."
echo "Version is $VERSION."
echo "SD card device is $SDCARD."
mkdir -p $LOGDIR 2> /dev/null
check_board
check_compiler
check_hsi
check_vivado
check_sdcard
echo "And so it begins ..."
################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Fetching Linux kernel and U-Boot sources ..."
else
	echo "Fetching Linux kernel, U-Boot sources and PyNQ default image ..."
fi
FETCH_LINUX_OK=$(get_linux; echo $? &)
FETCH_UBOOT_OK=$(get_u-boot; echo $? &)
FETCH_PYNQ_OK=$(if [[ $BOARD == "pynq" ]]; then get_pynq_image; fi; echo $? &)
wait
if [[ $FETCH_LINUX_OK -ne 0 ]]; then
	echo "Fetching Linux failed, check logs.."
	exit 1
fi
if [[ $FETCH_UBOOT_OK -ne 0 ]]; then
	echo "Fetching U-Boot failed, check logs."
	exit 1
fi
if [[ $FETCH_PYNQ_OK -ne 0 ]]; then
	echo "Fetching PyNQ failed, check logs."
	exit 1
fi
################################################################################
echo "Ok, got the sources, will build now ..."
echo "Building Linux kernel (output in $BUILD_LINUX_LOG) and U-Boot tools (output in $BUILD_UBOOT_LOG)..."
BUILD_LINUX_OK=$(build_linux; echo $? &)
BUILD_UBOOT_OK=$(build_u-boot; echo $? &)
wait
if [[ $BUILD_LINUX_OK -ne 0 ]]; then
	echo "Building Linux failed, check log: $BUILD_LINUX_LOG"
	exit 1
fi
if [[ $BUILD_UBOOT_OK -ne 0 ]]; then
	echo "Building U-Boot failed, check log: $BUILD_UBOOT_LOG"
	exit 1
fi
################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and uImage (output in $BUILD_UIMAGE_LOG) ..."
else
	echo "Building uImage (output in $BUILD_UIMAGE_LOG) ..."
fi
BUILD_UIMAGE_OK=$(build_uimage; echo $? &)
BUILD_SSBL_OK=$(if [[ $BOARD != "pynq" ]]; then build_ssbl; fi; echo $? &)
wait
if [[ $BUILD_UIMAGE_OK -ne 0 ]]; then
	"Building uImage failed, check log: $BUILD_UIMAGE_LOG"
	exit 1
fi
if [[ $BUILD_SSBL_OK -ne 0 ]]; then
	"Building U-Boot SSBL failed, check log: $BUILD_SSBL_LOG"
	exit 1
fi
################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Build FSBL (output in $BUILD_FSBL_LOG) ..."
	BUILD_FSBL_OK=$(build_fsbl; echo $? &)
	wait
	if [[ $BUILD_FSBL_OK -ne 0 ]]; then
		"Building FSBL failed, check log: $BUILD_FSBL_LOG"
		exit 1
	fi
	echo "Building devicetree (output in $BUILD_DEVICETREE_LOG) and generating BOOT.BIN (output in $BUILD_BOOTBIN_LOG) ..."
	BUILD_BOOTBIN_OK=$(build_bootbin; echo $? &)
	BUILD_DEVICETREE_OK=$(build_devtree; echo $? &)
	wait
	if [[ $BUILD_BOOTBIN_OK -ne 0 ]]; then
		echo "Building BOOT.BIN failed, check log: $BUILD_BOOTBIN_LOG"
		exit 1
	fi
	echo "Done - find BOOT.BIN is here: $DIR/BOOT.BIN."
	if [[ $BUILD_DEVICETREE_OK -ne 0 ]]; then
		echo "Building devicetree failed, check log: $BUILD_DEVICETREE_LOG"
		exit 1
	fi
else
	echo "Extract FSBL and devicetree from $PYNQ_IMAGE (output in $EXTRACT_BL_LOG) ..."
	EXTRACT_PYNQ_OK=$(extract_pynq_bl; echo $? &)
	wait
	if [[ ! -f $DIR/BOOT.BIN ]]; then
		echo "Extracting FSBL failed, check log: $EXTRACT_BL_LOG"
		exit 1
	fi
	if [[ ! -f $DIR/devicetree.dtb ]]; then
		echo "Extracting devicetree.dtb failed, check log: $EXTRACT_BL_LOG"
		exit 1
	fi
fi
################################################################################
echo "Extracting root FS (output in $EXTRACT_RFS_LOG) ..."
EXTRACT_RFS_OK=$(extract_pynq_rootfs; echo $? &)
wait
if [[ $EXTRACT_RFS_OK -ne 0 ]]; then
	echo "Extracting root FS failed, check log: $EXTRACT_RFS_LOG"
fi
################################################################################
if [[ -n $SDCARD ]]; then
	echo "Preparing $SDCARD, this may take a while (output in $PREPARE_SD_LOG) ..."
	PREPARE_SD_OK=$(prepare_sd; echo $? &)
	if [[ $PREPARE_SD_OK -ne 0 ]]; then
		echo "Preparing SD card failed, check log: $PREPARE_SD_LOG"
		exit 1
	fi
	sync
	echo "SD card $SDCARD successfully prepared, ready to boot!"
fi
