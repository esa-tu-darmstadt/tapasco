#!/bin/bash
BOARD=${1:-zedboard}
VERSION=${2:-2019.2}
IMGSIZE=${3:-7534}
SDCARD=${4:-}
JOBCOUNT=4
SCRIPTDIR="$(dirname $(readlink -f $0))"
DIR="$SCRIPTDIR/$BOARD/$VERSION"
LOGDIR="$DIR/logs"
ROOTFS_IMG="$SCRIPTDIR/rootfs.img"
PYNQ_VERSION="pynq_z1_v2.1"
PYNQ_IMAGE="$SCRIPTDIR/pynq/$PYNQ_VERSION.zip"
PYNQ_IMAGE_URL="http://files.digilent.com/Products/PYNQ/$PYNQ_VERSION.img.zip"
ARCH_ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
ARCH_ROOTFS_TAR_GZ="$DIR/arch_latest.tar.gz"
UDEV_RULES="$TAPASCO_HOME/platform/zynq/module/99-tapasco.rules"
OUTPUT_IMAGE="$DIR/${BOARD}_${VERSION}.img"
OPENSSL_URL="https://www.openssl.org/source/old/1.0.2/openssl-1.0.2n.tar.gz"
OPENSSL="$SCRIPTDIR/oldopenssl"
OPENSSL_TAR="$OPENSSL/openssl.tar.gz"
### LOGFILES ###################################################################
FETCH_LINUX_LOG="$LOGDIR/fetch-linux.log"
FETCH_UBOOT_LOG="$LOGDIR/fetch-uboot.log"
FETCH_PYNQ_IMG_LOG="$SCRIPTDIR/pynq/fetch-pynq-img.log"
FETCH_OPENSSL_LOG="$LOGDIR/fetch-openssl.log"
FETCH_ARM_TRUSTED_FIRMWARE_LOG="$LOGDIR/fetch-atfw.log"
FETCH_ARCH_LINUX_LOG="$LOGDIR/fetch-arch-linux.log"
BUILD_LINUX_LOG="$LOGDIR/build-linux.log"
BUILD_UBOOT_LOG="$LOGDIR/build-uboot.log"
BUILD_ARM_TRUSTED_FIRMWARE_LOG="$LOGDIR/build-atfw.log"
BUILD_SSBL_LOG="$LOGDIR/build-ssbl.log"
BUILD_UIMAGE_LOG="$LOGDIR/build-uimage.log"
BUILD_FSBL_LOG="$LOGDIR/build-fsbl.log"
BUILD_PMUFW_LOG="$LOGDIR/build-PMUFW.log"
BUILD_BOOTBIN_LOG="$LOGDIR/build-bootbin.log"
BUILD_DEVICETREE_LOG="$LOGDIR/build-devicetree.log"
BUILD_OUTPUT_IMAGE_LOG="$LOGDIR/build-output-image.log"
PREPARE_SD_LOG="$LOGDIR/prepare-sd.log"
EXTRACT_BL_LOG="$SCRIPTDIR/pynq/extract-bl.log"
EXTRACT_RFS_LOG="$SCRIPTDIR/pynq/extract-rfs.log"

HOSTCFLAGS=-I$OPENSSL/include
HOSTLDFLAGS="-L$OPENSSL/lib -lssl -lcrypto -ldl"
HOSTLOADLIBES=$HOSTLDFLAGS

print_usage () {
	cat << EOF
Usage: ${0##*/} BOARD VERSION [DISK SIZE] [DEVICE]
Build a boot image for the given BOARD and VERSION (git tag). If DEVICE is
given, repartition the device as a bootable SD card (WARNING: all data will
be lost).
	BOARD		one of zc706, zedboard, pyng, zcu102 or ultra96v2
	VERSION		Vivado Design Suite version, e.g., 2019.2
	DISK SIZE	Size of the image in MiB (optional, default: 7534)
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
		"zcu102")
			;;
        "ultra96v2")
            ;;
		*)
			echo "unknown board: $BOARD"
			echo "select one of zedboard, zc706, pynq or ultra96v2"
			print_usage
			;;
	esac
}

check_compiler () {
	which ${CROSS_COMPILE}gcc &> /dev/null ||
	error_exit "Compiler ${CROSS_COMPILE}gcc not found in path."
}

check_xsct() {
    which xsct &> /dev/null ||
	error_exit "Xilinx xcst tool is not in PATH, please source Vitis settings."
}

check_vivado () {
	which vivado &> /dev/null ||
	error_exit "Xilinx Vivado is not in PATH, please source Vivado settings."
}

check_tapasco () {
	[[ -n $TAPASCO_HOME ]] ||
	error_exit "TAPASCO_HOME is not set, please source setup.sh from TaPaSCo."
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
        #handling of xilinx sudden change in name convention
        if [[ $VERSION = 2019.2 ]]; then
            LINUX_VERSION=2019.2.01
        else
            LINUX_VERSION=$VERSION
        fi
		echo "Fetching linux $LINUX_VERSION ..."
		git clone -b xilinx-v$LINUX_VERSION --depth 1 https://github.com/xilinx/linux-xlnx.git $DIR/linux-xlnx ||
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

fetch_arm_trusted_firmware () {
    if [[ ! -d $DIR/arm-trusted-firmware ]]; then
        echo "Fetching arm-trusted-firmware ..."
        git clone --depth 1 https://github.com/ARM-software/arm-trusted-firmware.git $DIR/arm-trusted-firmware ||
        return $(error_ret "$LINENO: could not clone arm-trusted-firmware")
    else
        echo "$DIR/arm-trusted-firmware already exists, skipping."
    fi
}

fetch_openssl () {
	if [[ ! -f $OPENSSL_TAR ]]; then
		echo "Fetching ancient OpenSSL 1.0.2 for U-Boot ..."
		mkdir -p $OPENSSL || return $(error_ret "$LINENO: could not create $OPENSSL")
		curl -s $OPENSSL_URL -o $OPENSSL_TAR ||
			return $(error_ret "$LINENO: could not fetch $OPENSSL_URL")
		cd $OPENSSL && tar xvzf $OPENSSL_TAR
	fi
}


extract_pynq_bl () {
	IMG=${PYNQ_VERSION}.img
	if [[ ! -f $SCRIPTDIR/pynq/BOOT.BIN ]]; then
		pushd $SCRIPTDIR/pynq &> /dev/null
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
		$DIR/linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o $DIR/devicetree.dtb $SCRIPTDIR/pynq/devicetree.dts ||
			return $(error_ret "$LINENO: could not build devicetree")
	else
		echo "$DIR/devicetree.dtb already exists, skipping."
	fi
	echo "BOOT.BIN and devicetree.dtb are ready in $DIR."
}

extract_pynq_rootfs () {
	IMG=${PYNQ_VERSION}.img
	if [[ ! -f $ROOTFS_IMG ]]; then
		IMG=$SCRIPTDIR/pynq/${PYNQ_VERSION}.img
		START=$(fdisk -l $IMG | awk 'END { print $2 }')
		COUNT=$(fdisk -l $IMG | awk 'END { print $4 }')
		echo "Extracting root image from $IMG, start=$START and count = $COUNT"
		dd if=$IMG of=$ROOTFS_IMG skip=$START count=$COUNT ||
			return $(error_ret "$LINENO: extracting rootfs via dd failed")
	else
		echo "$ROOTFS_IMG already exists, skipping."
	fi
}

fetch_arch_linux() {
    if [[ ! -f $ARCH_ROOTFS_TAR_GZ ]]; then
        echo "Fetching arch linux rootfs..."
        curl -L -s $ARCH_ROOTFS_URL -o $ARCH_ROOTFS_TAR_GZ|| 
        return $(error_ret "$LINENO: could not fetch $ARCH_ROOTFS_URL")
    else
        echo "$ARCH_ROOTFS_TAR_GZ already exists, skipping."
    fi
}

build_openssl () {
	if [[ ! -f $OPENSSL/lib/libssl.a ]]; then
		cd $OPENSSL/openssl-1.0.2n
		make distclean
		./config --prefix=$OPENSSL || return $(error_ret "$LINENO: could not configure OpenSSL")
		make -j $JOBCOUNT || return $(error_ret "$LINENO: could not build OpenSSL")
		make install || return $(error_ret "$LINENO: could not install OpenSSL")
	else
		echo "$OPENSSL/libssl.a already exists, skipping"
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
            "ultra96v2")
                DEFCONFIG=avnet_ultra96_rev1_defconfig
                ;;
			"pynq")
				DEFCONFIG=zynq_zed_defconfig
				;;
            "zcu102")
                DEFCONFIG=xilinx_zynqmp_zcu102_rev1_0_defconfig
                ;;
			*)
				return $(error_ret "unknown board: $BOARD")
				;;
		esac
		cd $DIR/u-boot-xlnx
		make CROSS_COMPILE=$CROSS_COMPILE ARCH=$ARCH $DEFCONFIG ||
		return $(error_ret "$LINENO: could not make defconfig $DEFCONFIG")
        if [[ $BOARD != ultra96v2 ]]; then
            build_openssl
		    make CROSS_COMPILE=$CROSS_COMPILE ARCH=$ARCH HOSTCFLAGS=$HOSTCFLAGS HOSTLDFLAGS="$HOSTLDFLAGS" tools -j $JOBCOUNT ||
			    return $(error_ret "$LINENO: could not build u-boot tools")
        fi
	else

		echo "$DIR/u-boot-xlnx/tools/mkimage already exists, skipping."
	fi
}

build_linux () {
    if [[ ! $ARCH = arm64 ]]; then
	    if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/Image ]]; then
		    echo "Building linux $VERSION .."
		    DEFCONFIG=tapasco_zynq_defconfig
		    CONFIGFILE="$SCRIPTDIR/configs/tapasco_zynq_defconfig"
		    cp $CONFIGFILE $DIR/linux-xlnx/arch/arm/configs/ ||
			    return $(error_ret "$LINENO: could not copy config")
		    cd $DIR/linux-xlnx
		    make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG ||
			    return $(error_ret "$LINENO: could not make defconfig")
		    make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm -j $JOBCOUNT ||
			    return $(error_ret "$LINENO: could not build kernel")
	    else
		    echo "$DIR/linux-xlnx/arch/arm/boot/Image already exists, skipping."
	    fi
    else
        if [[ ! -e $DIR/linux-xlnx/arch/arm64/boot/Image ]]; then
		    echo "Building linux $VERSION for arm64.."
            DEFCONFIG=tapasco_zynqmp_defconfig
		    CONFIGFILE="$SCRIPTDIR/configs/tapasco_zynqmp_defconfig"
            cp $CONFIGFILE $DIR/linux-xlnx/arch/arm64/configs/ ||
			    return $(error_ret "$LINENO: could not copy config")
            cd $DIR/linux-xlnx
            make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm64 $DEFCONFIG ||
                return $(error_ret "$LINENO: could not make defconfig")
            make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm64 -j $JOBCOUNT ||  
			    return $(error_ret "$LINENO: could not build kernel")
           case $BOARD in
		        "ultra96v2")
                    cp $DIR/linux-xlnx/arch/arm64/boot/dts/xilinx/avnet-ultra96-rev1.dtb $DIR/devicetree.dtb || 
                    return $(error_ret "$LINENO: could not copy device tree");
                    ;;
                "zcu102")
                    cp $DIR/linux-xlnx/arch/arm64/boot/dts/xilinx/zynqmp-zcu102-revB.dtb $DIR/devicetree.dtb ||
                    return $(error_ret "$LINENO: could not copy device tree");
            esac
        else
            echo "$DIR/linux-xlnx/arch/arm64/boot/Image already exists, skipping."
        fi
    fi
}

build_ssbl () {
	if [[ ! -e $DIR/u-boot-xlnx/u-boot ]]; then
		echo "Building second stage boot loader ..."
        cd $DIR/u-boot-xlnx
        if [[ $ARCH != arm64 ]]; then
		    DTC=$DIR/linux-xlnx/scripts/dtc/dtc
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm DTC=$DTC HOSTCFLAGS=$HOSTCFLAGS HOSTLDFLAGS="$HOSTLDFLAGS" u-boot ||
			return $(error_ret "$LINENO: could not build u-boot")
        else
            make CROSS_COMPILE=$CROSS_COMPILE 
        fi
	else
		echo "$DIR/u-boot-xlnx/u-boot already exists, skipping."
	fi

    if [[$ARCH != arm64 ]]; then
	    cp $DIR/u-boot-xlnx/u-boot $DIR/u-boot-xlnx/u-boot.elf ||
		    return $(error_ret "$LINENO: could not copy to $DIR/u-boot-xlnx/u-boot.elf failed")
    fi
}

build_uimage () {
	if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/uImage ]]; then
		echo "Building uImage ..."
		cd $DIR/linux-xlnx
		export PATH=$PATH:$DIR/u-boot-xlnx/tools 
		make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm UIMAGE_LOADADDR=0x8000 uImage -j $JOBCOUNT ||
			return $(error_ret "$LINENO: could not build uImage")
	else
		echo "$DIR/linux-xlnx/arch/arm/boot/uImage already exists, skipping."
	fi
}

build_fsbl () {
	if [[ ! -f $DIR/fsbl/executable.elf ]]; then
		mkdir -p $DIR/fsbl || return $(error_ret "$LINENO: could not create $DIR/fsbl")
        if [[  $ARCH != arm64 ]]; then
#How could \$env(TAPASCO_HOME)/platform/$BOARD/platform.json ever work? The platform files are located @ \$env(TAPASCO_HOME)/toolflow/vivado/platform/$BOARD/platform.json...
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
set ps [tapasco::ip::create_ps "ps7" \$board_preset 100]
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
hsi generate_app -hw [hsi open_hw_design $BOARD.hdf] -os standalone -proc ps7_cortexa9_0 -app zynq_fsbl -compile -sw fsbl -dir .
EOF
        else 
            pushd $DIR/fsbl > /dev/null &&
		    cat > project.tcl << EOF
package require json

set platform_file [open "\$env(TAPASCO_HOME)/toolflow/vivado/platform/$BOARD/platform.json" r]
set json [read \$platform_file]
close \$platform_file
set platform [::json::json2dict \$json]

source "\$env(TAPASCO_HOME)/toolflow/vivado/common/common.tcl"
source "\$env(TAPASCO_HOME)/toolflow/vivado/platform/common/platform.tcl"
source "\$env(TAPASCO_HOME)/toolflow/vivado/platform/$BOARD/$BOARD.tcl"

create_project -force $BOARD $BOARD -part [dict get \$platform "Part"]
set board_part ""
if {[dict exists \$platform "BoardPart"]} {
	set board_part [dict get \$platform "BoardPart"]
	set_property board_part \$board_part [current_project]
}
create_bd_design -quiet "system"
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/maxihpm1_fpd_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
validate_bd_design
make_wrapper -files [get_files $DIR/fsbl/$BOARD/$BOARD.srcs/sources_1/bd/system/system.bd] -top
add_files -norecurse $DIR/fsbl/$BOARD/$BOARD.srcs/sources_1/bd/system/hdl/system_wrapper.v
update_compile_order -fileset sources_1
generate_target all [get_files $DIR/fsbl/$BOARD/$BOARD.srcs/sources_1/bd/system/system.bd]
write_hw_platform -fixed -force  -file $BOARD.xsa
puts "XSA in $BOARD.xsa, done"
exit
EOF
        cat > hsi.tcl << EOF
hsi generate_app -hw [hsi open_hw_design $BOARD.xsa] -proc psu_cortexa53_0 -os standalone -app zynqmp_fsbl -compile -sw fsbl -dir .
EOF
        fi
        
		vivado -nolog -nojournal -notrace -mode batch -source project.tcl ||
			return $(error_ret "$LINENO: Vivado could not build project")
		xsct hsi.tcl ||
			return $(error_ret "$LINENO: hsi could not build FSBL")
	else
		echo "$BOARD/fsbl/executable.elf already exists, skipping."
	fi
}

build_pmufw() {
    if [[ ! -f $DIR/pmufw/executable.elf ]]; then
		mkdir -p $DIR/pmufw || return $(error_ret "$LINENO: could not create $DIR/pmufw")
        pushd $DIR/pmufw > /dev/null &&
        cat > pmufw.tcl << EOF
hsi generate_app -hw [hsi open_hw_design $DIR/fsbl/$BOARD.xsa] -os standalone -proc psu_pmu_0 -app zynqmp_pmufw -compile -sw pmufw -dir .
EOF
        xsct pmufw.tcl || 
            return $(error_ret "$LINENO: hsi could not build pmu firmware")

    else
		echo "$BOARD/pmufw/executable.elf already exists, skipping."
	fi
}

build_arm_trusted_firmware() {
    if [[ ! -f $DIR/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf ]]; then
        echo "Building Arm Trusted Firmware for ZynqMP ..."
        cd $DIR/arm-trusted-firmware
        make CROSS_COMPILE=$CROSS_COMPILE PLAT=zynqmp RESET_TO_BL31=1
    else 
        echo "$BOARD/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf already exists, skipping."
    fi
}

build_bootbin () {
    if [[ ! -f $DIR/BOOT.BIN ]]; then
	    echo "Building BOOT.BIN ..."
        if [[ $ARCH = arm64 ]]; then 
            cat > $DIR/bootimage.bif << EOF
                image: {
                    [bootloader,destination_cpu=a53-0] $DIR/fsbl/executable.elf
                    [pmufw_image] $DIR/pmufw/executable.elf
                    [destination_cpu=a53-0,exception_level=el-3,trustzone] $DIR/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf 
                    [destination_cpu=a53-0, exception_level=el-2] $DIR/u-boot-xlnx/u-boot.elf
                }
EOF
            bootgen -arch zynqmp -image $DIR/bootimage.bif -w on -o $DIR/BOOT.BIN ||
    		    return $(error_ret "$LINENO: could not generate BOOT.bin")
        else
    	    cat > $DIR/bootimage.bif << EOF
                image : {
    	            [bootloader]$DIR/fsbl/executable.elf
    	            $DIR/u-boot-xlnx/u-boot.elf
                }
EOF
        bootgen -image $DIR/bootimage.bif -w on -o $DIR/BOOT.BIN ||
    		return $(error_ret "$LINENO: could not generate BOOT.bin")
        fi
    	echo "$DIR/BOOT.BIN ready."
    else
        echo "$DIR/BOOT.BIN already exists, skipping."
    fi
}

build_devtree () {
	echo "Building devicetree ..."
	case $BOARD in
		"zedboard")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
			cat $SCRIPTDIR/misc/zynq-7000.dtsi.patch | patch $DIR/zynq-7000.dtsi &&
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts
			echo >> $DIR/devicetree.dts
			echo "/include/ \"$SCRIPTDIR/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
			;;
		"zc706")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
			cat $SCRIPTDIR/misc/zynq-7000.dtsi.patch | patch $DIR/zynq-7000.dtsi &&
			cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
			cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts
			echo >> $DIR/devicetree.dts
			echo "/include/ \"$SCRIPTDIR/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
			;;
        "ultra96v2")
            #work around: Re-compile dts from dtb generated by linux-build and add tapasco related interrupts
            $DIR/linux-xlnx/scripts/dtc/dtc -I dtb -O dts -o $DIR/devicetree.dts $DIR/devicetree.dtb
            echo "/include/ \"$SCRIPTDIR/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
            ;;
        "zcu102")
            $DIR/linux-xlnx/scripts/dtc/dtc -I dtb -O dts -o $DIR/devicetree.dts $DIR/devicetree.dtb
            echo "/include/ \"$SCRIPTDIR/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts
	esac
	$DIR/linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o $DIR/devicetree.dtb $DIR/devicetree.dts ||
		return $(error_ret "$LINENO: could not build devicetree.dtb")
	echo "$DIR/devicetree.dtb ready."
}

build_output_image () {
	# size of image (in MiB)
	IMGSIZE=${1:-7534}
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
		dusudo sync
		echo "Mounting partitions in $OUTPUT_IMAGE ..."
		dusudo kpartx -av $OUTPUT_IMAGE ||
			return $(error_ret "$LINENO: could not kpartx -a $OUTPUT_IMAGE")
		sleep 3
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
    if [[ $ARCH == arm64 ]]; then
        echo "Copying $DIR/linux-xlnx/arch/arm64/boot/Image to $TO ..."
        dusudo cp $DIR/linux-xlnx/arch/arm64/boot/Image $TO ||
		    echo >&2 "$LINENO: WARNING: could not copy Image"
    else
	    echo "Copying $DIR/linux-xlnx/arch/arm/boot/uImage to $TO ..."
	    dusudo cp $DIR/linux-xlnx/arch/arm/boot/uImage $TO ||
		    echo >&2 "$LINENO: WARNING: could not copy uImage"
        echo "Copying uenv/uEnv-$BOARD.txt to $TO/uEnv.txt ..."
        dusudo cp uenv/uEnv-$BOARD.txt $TO/uEnv.txt ||
		    echo >&2 "$LINENO: WARNING: could not copy uEnv.txt"
    fi
	echo "Copying $DIR/devicetree.dtb to $TO ..."
	dusudo cp $DIR/devicetree.dtb $TO || echo >&2 "$LINENO: WARNING: could copy devicetree"
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
	dusudo sh -c "sed -i "s/pynq/$BOARD/g" $TO/etc/hosts" ||
		echo >&2 "$LINENO: WARNING: could not update /etc/hosts"
	echo "Setting env vars ... "
	dusudo sh -c "echo export LINUX_HOME=/linux-xlnx >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env var LINUX_HOME"
	dusudo sh -c "echo export TAPASCO_HOME=~/tapasco >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env var TAPASCO_HOME"
	dusudo sh -c "echo export PATH=\\\$PATH:\\\$TAPASCO_HOME/bin >> $TO/home/xilinx/.bashrc" ||
		echo >&2 "$LINENO: WARNING: could not set env PATH."
	echo "Replacing rc.local ... "
	dusudo sh -c "cp --no-preserve=ownership $SCRIPTDIR/misc/rc.local $TO/etc/rc.local" ||
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

if [ -z ${CROSS_COMPILE+x} ]; then 
    if [[ $BOARD = ultra96v2 ]] || [[ $BOARD = zcu102 ]]; then
        CROSS_COMPILE=aarch64-linux-gnu-
        ARCH=arm64
    else
        CROSS_COMPILE=arm-linux-gnueabihf-
        ARCH=arm
    fi
fi
echo "Processor architecture is set to $ARCH. "
echo "Cross compiler ABI is set to $CROSS_COMPILE."
echo "Board is $BOARD."
echo "Version is $VERSION."
echo "SD card device is $SDCARD."
echo "Image size: $IMGSIZE MiB"
if [[ $ARCH  != arm64 ]]; then echo "OpenSSL dir: $OPENSSL"; fi
check_board
check_compiler
check_xsct
check_vivado
check_image_tools
check_sdcard
read -p "Enter sudo password: " -s SUDOPW
[[ -n $SUDOPW ]] || error_exit "dusudo password may not be empty"
dusudo true || error_exit "sudo password seems to be wrong?"
mkdir -p $LOGDIR 2> /dev/null
mkdir -p `dirname $PYNQ_IMAGE` 2> /dev/null
printf "\nAnd so it begins ...\n"
################################################################################
echo "Fetching Linux kernel, U-Boot sources, rootfs and additional tools ..."
mkdir -p `dirname $FETCH_PYNQ_IMG_LOG` &> /dev/null
fetch_linux &> $FETCH_LINUX_LOG &
FETCH_LINUX_OK=$!
fetch_u-boot &> $FETCH_UBOOT_LOG &
FETCH_UBOOT_OK=$!
if [[ $ARCH != arm64 ]]; then
    fetch_pynq_image &> $FETCH_PYNQ_IMG_LOG &
    FETCH_PYNQ_OK=$!
    fetch_openssl &> $FETCH_OPENSSL_LOG &
    FETCH_OPENSSL_OK=$!
else
    fetch_arm_trusted_firmware &> $FETCH_ARM_TRUSTED_FIRMWARE_LOG &
    FETCH_ARM_TRUSTED_FIRMWARE_OK=$!
    fetch_arch_linux &> $FETCH_ARCH_LINUX_LOG &
    FETCH_ARCH_LINUX_OK=$!
fi

wait $FETCH_LINUX_OK   || error_exit "Fetching Linux failed, check log: $FETCH_LINUX_LOG"
wait $FETCH_UBOOT_OK   || error_exit "Fetching U-Boot failed, check logs: $FETCH_UBOOT_LOG"
if [[ $BOARD != ultra96v2 ]]; then
    wait $FETCH_PYNQ_OK    || error_exit "Fetching PyNQ failed, check log: $FETCH_PYNQ_IMG_LOG"
    wait $FETCH_OPENSSL_OK || error_exit "Fetching OpenSSL failed, check log: $FETCH_OPENSSL_LOG"
else
    wait $FETCH_ARM_TRUSTED_FIRMWARE_OK || error_exit "Fetching ARM Trusted Firmware failed, check log: $FETCH_ARM_TRUSTED_FIRMWARE_LOG"   
    wait $FETCH_ARCH_LINUX_OK || error_exit "Fetching Arch Linux Rootfs failed, check log: $FETCH_BSDTAR_LOG"
fi

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
    if [[ $ARCH = arm64 ]]; then 
        echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and Arm Trusted Firmware (output in $BUILD_ARM_TRUSTED_FIRMWARE) ... "
        build_arm_trusted_firmware &> $BUILD_ARM_TRUSTED_FIRMWARE_LOG &
            BUILD_ARM_TRUSTED_FIRMWARE_OK=$!
        wait $BUILD_ARM_TRUSTED_FIRMWARE || error_exit "Building Arm Trusted Firmware failed, check log: $ARM_TRUSTED_FIRMWARE_LOG"
    else
	    echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and uImage (output in $BUILD_UIMAGE_LOG) ..."
    fi
else
	echo "Building uImage (output in $BUILD_UIMAGE_LOG) ..."
fi
if [[ $ARCH != arm64 ]]; then build_uimage &> $BUILD_UIMAGE_LOG; fi &
BUILD_UIMAGE_OK=$!
if [[ $BOARD != "pynq" ]]; then build_ssbl &> $BUILD_SSBL_LOG; fi &
BUILD_SSBL_OK=$!
wait $BUILD_UIMAGE_OK || error_exit "Building uImage failed, check log: $BUILD_UIMAGE_LOG"
wait $BUILD_SSBL_OK || error_exit "Building U-Boot SSBL failed, check log: $BUILD_SSBL_LOG"

################################################################################
if [[ $BOARD != "pynq" ]]; then
	echo "Build FSBL (output in $BUILD_FSBL_LOG) ..."
	build_fsbl &> $BUILD_FSBL_LOG &
	BUILD_FSBL_OK=$!
	wait $BUILD_FSBL_OK || error_exit "Building FSBL failed, check log: $BUILD_FSBL_LOG"

    if [[ $ARCH = arm64 ]]; then 
        echo "Building pmufw (output in $BUILD_PMUFW_LOG), devicetree (output in $BUILD_DEVICETREE_LOG) and generating BOOT.BIN (output in $BUILD_BOOTBIN_LOG) ..."
        build_pmufw &> $BUILD_PMUFW_LOG &
            BUILD_PMUFW_OK=$!
        wait $BUILD_PMUFW_OK || error_exit "Building PMUFW failed, check log: $BUILD_PMUFW_LOG"
    else
        echo "Building devicetree (output in $BUILD_DEVICETREE_LOG) and generating BOOT.BIN (output in $BUILD_BOOTBIN_LOG) ..."
    fi

    build_devtree &> $BUILD_DEVICETREE_LOG &
    BUILD_DEVICETREE_OK=$!

	build_bootbin &> $BUILD_BOOTBIN_LOG &
	BUILD_BOOTBIN_OK=$!

    wait $BUILD_DEVICETREE_OK || error_exit "Building devicetree failed, check log: $BUILD_DEVICETREE_LOG"
	wait $BUILD_BOOTBIN_OK || error_exit "Building BOOT.BIN failed, check log: $BUILD_BOOTBIN_LOG"
	echo "Done - find BOOT.BIN here: $DIR/BOOT.BIN."
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
error_exit "Done."
################################################################################
echo "Extracting root FS (output in $EXTRACT_RFS_LOG) ..."
extract_pynq_rootfs &> $EXTRACT_RFS_LOG
[[ $? -eq 0 ]] || error_exit "Extracting root FS failed, check log: $EXTRACT_RFS_LOG"
################################################################################
echo "Building image in $OUTPUT_IMAGE (output in $BUILD_OUTPUT_IMAGE_LOG) ..."
build_output_image $IMGSIZE &> $BUILD_OUTPUT_IMAGE_LOG
if [[ $? -ne 0 ]]; then
	rm -f $OUTPUT_IMAGE &> /dev/null
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
