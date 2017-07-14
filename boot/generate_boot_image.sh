#!/bin/bash
BOARD=${1:-zedboard}
VERSION=${2:-2016.4}
IMGSIZE=${3:-8192}
SDCARD=${4:-}
DIR="$BOARD/$VERSION"
LOGDIR="$DIR/logs"
CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabihf-}
ROOTFS_IMG="$PWD/rootfs.img"
PYNQ_VERSION="pynq_z1_image_2017_02_10"
PYNQ_IMAGE="$PWD/pynq/$PYNQ_VERSION.zip"
PYNQ_IMAGE_URL="https://s3-us-west-2.amazonaws.com/digilent/Products/PYNQ/$PYNQ_VERSION.zip"
UDEV_RULES="$TAPASCO_HOME/platform/zynq/module/99-tapasco.rules"
OUTPUT_IMAGE="$DIR/${BOARD}_${VERSION}.img"
### LOGFILES ###################################################################
FETCH_LINUX_LOG="$PWD/$LOGDIR/fetch-linux.log"
FETCH_UBOOT_LOG="$PWD/$LOGDIR/fetch-uboot.log"
FETCH_PYNQ_IMG_LOG="$PWD/pynq/fetch-pynq-img.log"
BUILD_LINUX_LOG="$PWD/$LOGDIR/build-linux.log"
BUILD_UBOOT_LOG="$PWD/$LOGDIR/build-uboot.log"
BUILD_SSBL_LOG="$PWD/$LOGDIR/build-ssbl.log"
BUILD_UIMAGE_LOG="$PWD/$LOGDIR/build-uimage.log"
BUILD_FSBL_LOG="$PWD/$LOGDIR/build-fsbl.log"
BUILD_BOOTBIN_LOG="$PWD/$LOGDIR/build-bootbin.log"
BUILD_DEVICETREE_LOG="$PWD/$LOGDIR/build-devicetree.log"
BUILD_OUTPUT_IMAGE_LOG="$PWD/$LOGDIR/build-output-image.log"
PREPARE_SD_LOG="$PWD/$LOGDIR/prepare-sd.log"
EXTRACT_BL_LOG="$PWD/pynq/extract-bl.log"
EXTRACT_RFS_LOG="$PWD/pynq/extract-rfs.log"

print_usage () {
	cat << EOF
Usage: ${0##*/} BOARD VERSION [DEVICE] [DISK SIZE]
Build a boot image for the given BOARD and VERSION (git tag). If DEVICE is
given, repartition the device as a bootable SD card (WARNING: all data will
be lost).
	BOARD		one of zc706, zedboard
	VERSION		Vivado Design Suite version, e.g., 2016.4
	DISK SIZE	Size of the image in MiB (optional, default: 8192)
	DEVICE		SD card device, e.g., /dev/sdb (optional)
EOF
	exit 1
}

dusudo () {
	[[ -z $1 ]] || echo $SUDOPW | sudo --stdin "$@"
}

error_exit () {
	echo ${1:-"unknown error"} >&2 && exit 1
}

error_ret () {
	echo ${1:-"error in script"} >&2 && return 1
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
	which ${CROSS_COMPILE}gcc &> /dev/null ||
	error_exit "Compiler ${CROSS_COMPILE}gcc not found in path."
}

check_hsi () {
	which hsi &> /dev/null ||
	error_exit "Xilinx hsi tool is not in PATH, please source Vivado settings."
}

check_vivado () {
	which vivado &> /dev/null ||
	error_exit "Xilinx Vivado is not in PATH, please source Vivado settings."
}

check_bootgen () {
	which bootgen &> /dev/null ||
	error_exit "Xilinx bootgen tool is not in PATH, please source Vivado settings."
}

check_image_tools () {
	which kpartx &> /dev/null ||
	error_exit "Partitioning helper 'kpartx' not found, please install package."
}

check_sdcard () {
	[[ -z $SDCARD || -e $SDCARD ]] ||
	error_exit "SD card device $SDCARD does not exist!"
}

fetch_linux () {
	if [[ ! -d $DIR/linux-xlnx ]]; then
		echo "Fetching linux $VERSION ..."
		git clone -b xilinx-v$VERSION --depth 1 https://github.com/xilinx/linux-xlnx.git $DIR/linux-xlnx ||
		return $(error_ret "$LINENO: could not clone linux git")
	else
		echo "$DIR/linux-xln already exists, skipping."
	fi
}

fetch_u-boot () {
	if [[ ! -d $DIR/u-boot-xlnx ]]; then
		echo "Fetching u-boot $VERSION ..."
		git clone -b xilinx-v$VERSION --depth 1 https://github.com/xilinx/u-boot-xlnx.git $DIR/u-boot-xlnx ||
		return $(error_ret "$LINENO: could not clone u-boot git")
	else
		echo "$DIR/u-boot-xlnx already exists, skipping."
	fi
}

fetch_pynq_image () {
	IMG=${PYNQ_VERSION}.img
	BD=`dirname $PYNQ_IMAGE`
	if [[ ! -f $PYNQ_IMAGE ]]; then
		echo "Fetching PyNQ standard image ..."
		mkdir -p $BD || return $(error_ret "$LINENO: could not create $BD")
		curl -s $PYNQ_IMAGE_URL -o $PYNQ_IMAGE ||
		return $(error_ret "$LINENO: could not fetch $PYNQ_IMAGE_URL")
	fi
	if [[ ! -f $PWD/pynq/$IMG ]]; then
		echo "Unzipping $PYNQ_IMAGE to extract $IMG ..."
		pushd $PWD/pynq &&
		unzip -u $PYNQ_IMAGE &&
		popd > /dev/null
	fi
}

extract_pynq_bl () {
	IMG=${PYNQ_VERSION}.img
	if [[ ! -f $PWD/pynq/BOOT.BIN ]]; then
		pushd $PWD/pynq &> /dev/null
		mkdir -p img ||
			return $(error_ret "$LINENO: could not create img dir")
		dusudo mount -oloop,offset=1M $IMG img ||
			return $(error_ret "$LINENO: could not mount $IMAGE")
		dusudo cp img/BOOT.BIN $VERSION/BOOT.BIN ||
			return $(error_ret "$LINENO: could not copy img/BOOT.BIN")
		dusudo chown $USER $VERSION/BOOT.BIN ||
			return $(error_ret "$LINENO: could not chown $USER $VERSION/BOOT.BIN")
		dusudo cp img/uEnv.txt ../uenv/uEnv-pynq.txt ||
			return $(error_ret "$LINENO: could not cp img/uEnv.txt")
		dusudo chown $USER ../uenv/uEnv-pynq.txt ||
			return $(error_ret "$LINENO: could not chown $USER uenv/uEnv-pynq.txt")
		dusudo umount img ||
			return $(error_ret "$LINENO: could not umount img")
		rmdir img ||
			return $(error_ret "$LINENO: could not remove img")
		popd &> /dev/null
	else
		echo "$DIR/BOOT.BIN already exists, skipping."
	fi
	if [[ ! -f $DIR/devicetree.dtb ]]; then
		$DIR/linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o $DIR/devicetree.dtb $PWD/pynq/devicetree.dts ||
			return $(error_ret "$LINENO: could not build devicetree")
	else
		echo "$DIR/devicetree.dtb already exists, skipping."
	fi
	echo "BOOT.BIN and devicetree.dtb are ready in $DIR."
}

extract_pynq_rootfs () {
	IMG=${PYNQ_VERSION}.img
	if [[ ! -f $ROOTFS_IMG ]]; then
		IMG=$PWD/pynq/${PYNQ_VERSION}.img
		START=$(fdisk -l $IMG | awk 'END { print $2 }')
		COUNT=$(fdisk -l $IMG | awk 'END { print $4 }')
		echo "Extracting root image from $IMG, start=$START and count = $COUNT"
		dd if=$IMG of=$ROOTFS_IMG skip=$START count=$COUNT ||
			return $(error_ret "$LINENO: extracting rootfs via dd failed")
	else
		echo "$ROOTFS_IMG already exists, skipping."
	fi
}

build_u-boot () {
	if [[ ! -e $DIR/u-boot-xlnx/tools/mkimage ]]; then
		echo "Building u-boot $VERSION ..."
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
			*)
				return $(error_ret "unknown board: $BOARD")
				;;
		esac
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG ||
			return $(error_ret "$LINENO: could make defconfig $DEFCONFIG")
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm tools ||
			return $(error_ret "$LINENO: could not build u-boot tools")
	else
		echo "$DIR/u-boot-xlnx/tools/mkimage already exists, skipping."
	fi
}

build_linux () {
	if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/Image ]]; then
		echo "Building linux $VERSION .."
		DEFCONFIG=tapasco_zynq_defconfig
		CONFIGFILE="$PWD/configs/tapasco_zynq_defconfig"
		cp $CONFIGFILE $DIR/linux-xlnx/arch/arm/configs/ ||
			return $(error_ret "$LINENO: could not copy config")
		make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG ||
			return $(error_ret "$LINENO: could not make defconfig")
		make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm -j ||
			return $(error_ret "$LINENO: could not build kernel")
	else
		echo "$DIR/linux-xlnx/arch/arm/boot/Image already exists, skipping."
	fi
}

build_ssbl () {
	if [[ ! -e $DIR/u-boot-xlnx/u-boot ]]; then
		echo "Building second stage boot loader ..."
		DTC=$PWD/$DIR/linux-xlnx/scripts/dtc/dtc
		make -C $DIR/u-boot-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm DTC=$DTC u-boot ||
			return $(error_ret "$LINENO: could not build u-boot")
	else
		echo "$DIR/u-boot-xlnx/u-boot already exists, skipping."
	fi
	cp $DIR/u-boot-xlnx/u-boot $DIR/u-boot-xlnx/u-boot.elf ||
		return $(error_ret "$LINENO: could not copy to $DIR/u-boot-xlnx/u-boot.elf failed")
}

build_uimage () {
	if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/uImage ]]; then
		echo "Building uImage ..."
		make -C $DIR/linux-xlnx CROSS_COMPILE=$CROSS_COMPILE ARCH=arm PATH=$PATH:$PWD/$DIR/u-boot-xlnx/tools UIMAGE_LOADADDR=0x8000 uImage ||
			return $(error_ret "$LINENO: could not build uImage")
	else
		echo "$DIR/linux-xlnx/arch/arm/boot/uImage already exists, skipping."
	fi
}

build_fsbl () {
	if [[ ! -f $DIR/fsbl/executable.elf ]]; then
		mkdir -p $DIR/fsbl || return $(error_ret "$LINENO: could not create $DIR/fsbl")
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
		vivado -nolog -nojournal -notrace -mode batch -source project.tcl ||
			return $(error_ret "$LINENO: Vivado could not build FSBL project")
		hsi -nolog -nojournal -notrace -mode batch -source hsi.tcl ||
			return $(error_ret "$LINENO: hsi could not build FSBL")
	else
		echo "$BOARD/fsbl/executable.elf already exists, skipping."
	fi
}

build_bootbin () {
	echo "Building BOOT.BIN ..."
	cat > $PWD/$DIR/bootimage.bif << EOF
image : {
	[bootloader]$PWD/$DIR/fsbl/executable.elf
	$PWD/$DIR/u-boot-xlnx/u-boot.elf
}
EOF
	bootgen -image $DIR/bootimage.bif -w on -o $DIR/BOOT.BIN ||
		return $(error_ret "$LINENO: could not generate BOOT.bin")
	echo "$DIR/BOOT.BIN ready."
}

build_devtree () {
	echo "Building devicetree ..."
	case $BOARD in
		"zedboard")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
			cat $PWD/misc/zynq-7000.dtsi.patch | patch $DIR/zynq-7000.dtsi &&
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts 
			echo >> $DIR/devicetree.dts
			echo "/include/ \"$PWD/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
			;;
		"zc706")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
			cat $PWD/misc/zynq-7000.dtsi.patch | patch $DIR/zynq-7000.dtsi &&
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts 
			echo >> $DIR/devicetree.dts
			echo "/include/ \"$PWD/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
			;;
	esac
	$DIR/linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o $DIR/devicetree.dtb $DIR/devicetree.dts ||
		return $(error_ret "$LINENO: could not build devicetree.dtb")
	echo "$DIR/devicetree.dtb ready."
}

build_output_image () {
	# size of image (in MiB)
	IMGSIZE=${1:-8192}
	# default root size: MAX - 358 MiB (converted to 512B sectors)
	ROOTSZ=${2:-$((($IMGSIZE - 358) * 1024 * 1024 / 512))}
	if [[ ! -f $OUTPUT_IMAGE ]]; then
		echo "Building $OUTPUT_IMAGE ($IMGSIZE MiB, rootfs $ROOTSZ sectors)..."
		echo "Creating empty disk image ..."
		dd if=/dev/zero of=$OUTPUT_IMAGE bs=1M count=$IMGSIZE conv=sparse ||
			return $(error_ret "$LINENO: could not init $OUTPUT_IMAGE")
		# remove all loopback devices
		dusudo losetup -D
		echo "Mounting image to loopback device ..."
		LOOPDEV=$(dusudo losetup -f --show $OUTPUT_IMAGE) ||
			return $(error_ret "$LINENO: could losetup $OUTPUT_IMAGE")
		echo "Partitioning image in $LOOPDEV ..."
		cat > $DIR/sfdisk.script << EOF
2048 204800 c, *
206848 $ROOTSZ 83 -
EOF
		dusudo sh -c "cat $DIR/sfdisk.script | sfdisk $LOOPDEV"
		if [[ $? -ne 0 ]]; then
			dusudo losetup -d $LOOPDEV
			return $(error_ret "$LINENO: could not partition $OUTPUT_IMAGE")
		fi
		echo "Unmounting image in $LOOPDEV ..."
		dusudo losetup -d $LOOPDEV
		echo "Mounting partitions in $OUTPUT_IMAGE ..."
		dusudo kpartx -a $OUTPUT_IMAGE ||
			return $(error_ret "$LINENO: could not kpartx -a $OUTPUT_IMAGE")
		LD=`basename $LOOPDEV`
		LD1=${LD}p1
		LD2=${LD}p2
		echo "Making BOOT partition in /dev/mapper/$LD1 ..."
		dusudo mkfs.vfat -F 32 -n BOOT /dev/mapper/$LD1 
		if [[ $? -ne 0 ]]; then
			dusudo kpartx -d $OUTPUT_IMAGE
			return $(error_ret "$LINENO: could not make BOOT partition")
		fi
		echo "Making Ext4 partition in /dev/mapper/$LD2 ..."
		dusudo mkfs.ext4 -F -L root /dev/mapper/$LD2
		if [[ $? -ne 0 ]]; then
			dusudo kpartx -d $OUTPUT_IMAGE
			return $(error_ret "$LINENO: could not make ROOT partition")
		fi
		echo "Copying files to BOOT ..."
		copy_files_to_boot /dev/mapper/$LD1
		if [[ $? -ne 0 ]]; then
			dusudo kpartx -d $OUTPUT_IMAGE
			return "$LINENO: copying files to boot failed"
		fi
		echo "Copying files to root ..."
		copy_files_to_root /dev/mapper/$LD2
		if [[ $? -ne 0 ]]; then
			dusudo kpartx -d $OUTPUT_IMAGE
			return "$LINENO: copying files to rootfs failed"
		fi
		echo "Unmounting partitions ..."
		dusudo kpartx -d $OUTPUT_IMAGE &&
		echo "Done, $OUTPUT_IMAGE is ready!"
	else
		echo "$OUTPUT_IMAGE already exists, skipping."
	fi
}

prepare_sd () {
	echo "dd'ing $OUTPUT_IMAGE to $SDCARD, this will take a while ..."
	dusudo dd if=$OUTPUT_IMAGE of=$SDCARD bs=10M ||
		return $(error_ret "$LINENO: could not dd $OUTPUT_IMAGE to $SDCARD")
	echo "$SDCARD ready."
}

copy_files_to_boot () {
	DEV=${1:-${SDCARD}1}
	TO="$DIR/`basename $DEV`"
	echo "Preparing BOOT partition $TO ..."
	mkdir -p $TO || return $(error_ret "$LINENO: could not create $TO")
	dusudo mount $DEV $TO || return $(error_ret "$LINENO: could not mount $DEV -> $TO")
	echo "Copying $DIR/BOOT.BIN to $TO ..."
	dusudo cp $DIR/BOOT.BIN $TO || echo >&2 "$LINENO: WARNING: could not copy BOOT.BIN"
	echo "Copying $DIR/linux-xlnx/arch/arm/boot/uImage to $TO ..."
	dusudo cp $DIR/linux-xlnx/arch/arm/boot/uImage $TO ||
		echo >&2 "$LINENO: WARNING: could not copy uImage"
	echo "Copying $DIR/devicetree.dtb to $TO ..."
	dusudo cp $DIR/devicetree.dtb $TO || echo >&2 "$LINENO: WARNING: could copy devicetree"
	echo "Copying uenv/uEnv-$BOARD.txt to $TO/uEnv.txt ..."
	dusudo cp uenv/uEnv-$BOARD.txt $TO/uEnv.txt ||
		echo >&2 "$LINENO: WARNING: could not copy uEnv.txt"
	dusudo umount $TO
	rmdir $TO 2> /dev/null &&
	echo "Boot partition ready."
}

copy_files_to_root () {
	DEV=${1:-${SDCARD}2}
	TO="$DIR/`basename $DEV`"
	echo "dd'ing rootfs onto second partition $TO, this will take a while ..."
	dusudo dd if=$ROOTFS_IMG of=$DEV bs=10M ||
		return $(error_ret "$LINENO: could not copy $ROOTFS_IMG to $DEV")
	dusudo resize2fs $DEV ||
		return $(error_ret "$LINENO: could not resize $DEV")
	mkdir -p $TO || return $(error_ret "$LINENO: could not create $TO")
	dusudo mount -onoacl $DEV $TO ||
		return $(error_ret "$LINENO: could not mount $DEV -> $TO")
	echo "Setting hostname to $BOARD ... "
	dusudo sh -c "echo $BOARD > $TO/etc/hostname" ||
		echo >&2 "$LINENO: WARNING: could not set hostname"
	echo "Updating /etc/hosts ..."
	dusudo sed -i "s/pynq/$BOARD/g" $TO/etc/hosts ||
		echo >&2 "$LINENO: WARNING: could not update /etc/hosts"
	echo "Setting env vars ... "
	dusudo sh -c "echo export LINUX_HOME=/linux-xlnx >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env var LINUX_HOME"
	dusudo sh -c "echo export TAPASCO_HOME=~/tapasco >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env var TAPASCO_HOME"
	dusudo sh -c "echo export PATH=\\\$PATH:\\\$TAPASCO_HOME/bin >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env PATH."
	echo "Replacing rc.local ... "
	dusudo sh -c "cp --no-preserve=ownership $PWD/misc/rc.local $TO/etc/rc.local" ||
		echo >&2 "$LINENO: WARNING: could not copy rc.local"
	if [[ $IMGSIZE -gt 4096 ]]; then
		echo "Copying linux tree to /linux-xlnx ..."
		dusudo sh -c "cp -r --no-preserve=ownership,timestamps $DIR/linux-xlnx $TO/linux-xlnx" ||
			echo >&2 "$LINENO: WARNING: could not copy linux-xlnx"
	else
		echo >&2 "$LINENO: WARNING: image size $IMGSIZE < 4096 MiB, not enough space to copy linux tree"
	fi
	echo "Copying udev rules ..."
	dusudo sh -c "cat $UDEV_RULES | sed 's/OWNER\"tapasco\"/OWNER=\"xilinx\"/g' | sed 's/GROUP=\"tapasco\"/GROUP=\"xilinx\"/g' | sed 's/tapasco:tapasco/xilinx:xilinx/g' > $TO/etc/udev/rules.d/99-tapasco.rules" ||
		echo >&2 "$LINENO: WARNING: could not write udev rules"
	echo "Removing Jupyter stuff from home ..."
	dusudo sh -c "find $TO/home/xilinx/* -maxdepth 0 | xargs rm -rf" ||
		echo >&2 "$LINENO: WARNING: could not delete Jupyter stuff"
	dusudo umount $TO
	rmdir $TO 2> /dev/null &&
	echo "RootFS partition ready."
}

################################################################################
################################################################################
echo "Cross compiler ABI is set to $CROSS_COMPILE."
echo "Board is $BOARD."
echo "Version is $VERSION."
echo "SD card device is $SDCARD."
echo "Image size: $IMGSIZE MiB"
check_board
check_compiler
check_hsi
check_vivado
check_image_tools
check_sdcard
read -p "Enter sudo password: " -s SUDOPW
[[ -n $SUDOPW ]] || error_exit "dusudo password may not be empty"
mkdir -p $LOGDIR 2> /dev/null
mkdir -p `dirname $PYNQ_IMAGE` 2> /dev/null
echo "And so it begins ..."
################################################################################
echo "Fetching Linux kernel, U-Boot sources and PyNQ default image ..."
mkdir -p `dirname $FETCH_PYNQ_IMG_LOG` &> /dev/null
fetch_linux &> $FETCH_LINUX_LOG &
FETCH_LINUX_OK=$!
fetch_u-boot &> $FETCH_UBOOT_LOG &
FETCH_UBOOT_OK=$!
fetch_pynq_image &> $FETCH_PYNQ_IMG_LOG &
FETCH_PYNQ_OK=$!

wait $FETCH_LINUX_OK || error_exit "Fetching Linux failed, check log: $FETCH_LINUX_LOG"
wait $FETCH_UBOOT_OK || error_exit "Fetching U-Boot failed, check logs: $FETCH_UBOOT_LOG"
wait $FETCH_PYNQ_OK  || error_exit "Fetching PyNQ failed, check log: $FETCH_PYNQ_IMG_LOG"

################################################################################
echo "Ok, got the sources, will build now ..."
echo "Building Linux kernel (output in $BUILD_LINUX_LOG) and U-Boot tools (output in $BUILD_UBOOT_LOG)..."
build_linux &> $BUILD_LINUX_LOG &
BUILD_LINUX_OK=$!
build_u-boot &> $BUILD_UBOOT_LOG &
BUILD_UBOOT_OK=$!
wait $BUILD_LINUX_OK || error_exit "Building Linux failed, check log: $BUILD_LINUX_LOG"
wait $BUILD_UBOOT_OK || error_exit "Building U-Boot failed, check log: $BUILD_UBOOT_LOG"
################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and uImage (output in $BUILD_UIMAGE_LOG) ..."
else
	echo "Building uImage (output in $BUILD_UIMAGE_LOG) ..."
fi
build_uimage &> $BUILD_UIMAGE_LOG &
BUILD_UIMAGE_OK=$!
if [[ $BOARD != "pynq" ]]; then build_ssbl &> $BUILD_SSBL_LOG; fi &
BUILD_SSBL_OK=$!
wait $BUILD_UIMAGE_OK || error_exit "Building uImage failed, check log: $BUILD_UIMAGE_LOG"
wait $BUILD_SSBL_OK || error_exit "Building U-Boot SSBL failed, check log: $BUILD_SSBL_LOG"
################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Build FSBL (output in $BUILD_FSBL_LOG) ..."
	build_fsbl &> $BUILD_FSBL_LOG &
	wait || error_exit "Building FSBL failed, check log: $BUILD_FSBL_LOG"

	echo "Building devicetree (output in $BUILD_DEVICETREE_LOG) and generating BOOT.BIN (output in $BUILD_BOOTBIN_LOG) ..."

	build_bootbin &> $BUILD_BOOTBIN_LOG &
	BUILD_BOOTBIN_OK=$!
	build_devtree &> $BUILD_DEVICETREE_LOG &
	BUILD_DEVICETREE_OK=$!
	wait $BUILD_BOOTBIN_OK || error_exit "Building BOOT.BIN failed, check log: $BUILD_BOOTBIN_LOG"
	echo "Done - find BOOT.BIN is here: $DIR/BOOT.BIN."
	wait $BUILD_DEVICETREE_OK || error_exit "Building devicetree failed, check log: $BUILD_DEVICETREE_LOG"
else
	echo "Extract FSBL and devicetree from $PYNQ_IMAGE (output in $EXTRACT_BL_LOG) ..."
	extract_pynq_bl &> $EXTRACT_BL_LOG &
	wait || error_exit "Extraction of FSBL and devicetree from $PYNQ_IMAGE failed, check log: $EXTRACT_BL_LOG"
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
extract_pynq_rootfs &> $EXTRACT_RFS_LOG
[[ $? -eq 0 ]] || error_exit "Extracting root FS failed, check log: $EXTRACT_RFS_LOG"
################################################################################
echo "Building image in $OUTPUT_IMAGE (output in $BUILD_OUTPUT_IMAGE_LOG) ..."
build_output_image $IMGSIZE &> $BUILD_OUTPUT_IMAGE_LOG
if [[ $? -ne 0 ]]; then
	# rm -f $OUTPUT_IMAGE &> /dev/null
	error_exit "Building output image failed, check log: $BUILD_OUTPUT_IMAGE_LOG"
fi
echo "SD card image ready: $OUTPUT_IMAGE"
################################################################################
if [[ -n $SDCARD ]]; then
	echo "Preparing $SDCARD, this may take a while (output in $PREPARE_SD_LOG) ..."
	prepare_sd &> $PREPARE_SD_LOG
	[[ $? -eq 0 ]] || error_exit "Preparing SD card failed, check log: $PREPARE_SD_LOG"
	sync &&
	echo "SD card $SDCARD successfully prepared, ready to boot!"
fi
