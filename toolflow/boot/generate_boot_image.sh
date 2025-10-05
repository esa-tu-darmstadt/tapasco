#!/bin/bash
BOARD=${1:-zedboard}
VERSION=${2:-2019.2}
IMGSIZE=${3:-7534}
SDCARD=${4:-}
JOBCOUNT=8
SCRIPTDIR="$(dirname $(readlink -f $0))"
DIR="$SCRIPTDIR/$BOARD/$VERSION"
LOGDIR="$DIR/logs"
LINUX_XLNX_URL="https://github.com/xilinx/linux-xlnx.git"
UBOOT_URL="https://github.com/xilinx/u-boot-xlnx.git"
ATF_URL="https://github.com/Xilinx/arm-trusted-firmware.git"
ARTYZ7_DTS_URL="https://raw.githubusercontent.com/Digilent/linux-digilent/master/arch/arm/boot/dts/zynq-artyz7.dts"
ROOTFS_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.2-base-armhf.tar.gz"
ROOTFS64_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.4-base-arm64.tar.gz"
ROOTFS_TAR_GZ="$DIR/ubuntu_armhf_20.04.tar.gz"
ROOTFS64_TAR_GZ="$DIR/ubuntu_arm64_22.04.tar.gz"
UDEV_RULES="$TAPASCO_HOME/platform/zynq/module/99-tapasco.rules"
OUTPUT_IMAGE="$DIR/${BOARD}_${VERSION}.img"
### LOGFILES ###################################################################
FETCH_LINUX_LOG="$LOGDIR/fetch-linux.log"
FETCH_UBOOT_LOG="$LOGDIR/fetch-uboot.log"
FETCH_ARM_TRUSTED_FIRMWARE_LOG="$LOGDIR/fetch-atfw.log"
FETCH_ROOTFS_LOG="$LOGDIR/fetch-rootfs.log"
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
OMIT_ROOT=false # if running as user, disabling tasks which require root is possible

print_usage() {
	cat << EOF
Usage: ${0##*/} BOARD VERSION [DISK SIZE] [DEVICE]
Build a boot image for the given BOARD and VERSION (git tag). If DEVICE is
given, repartition the device as a bootable SD card (WARNING: all data will
be lost).
	BOARD		one of zc706, zedboard, pyng, zcu102, ultra96v2, or kr260
	VERSION		Vivado Design Suite version, e.g., 2019.2
	DISK SIZE	Size of the image in MiB (optional, default: 5120)
	DEVICE		SD card device, e.g., /dev/sdb (optional)
EOF
	exit 1
}

append_if_not_exists(){
    #used for modifying kernel configs
	grep -qxF $1 $2 || echo $1 >> $2
}

dusudo() {
	[[ -z $1 ]] || echo $SUDOPW | sudo --stdin "$@"
}

error_exit() {
	echo ${1:-"unknown error"} >&2 && exit 1
}

error_ret() {
	echo ${1:-"error in script"} >&2 && return 1
}

check_board() {
	case $BOARD in
		"zedboard") ;;

		"zc706") ;;

		"pynq") ;;

		"zcu102") ;;

		"ultra96v2") ;;

		"kr260") ;;

		*)
			echo "unknown board: $BOARD"
			echo "select one of zedboard, zc706, pynq, zcu102, ultra96v2, or kr260"
			print_usage
			;;
	esac
}

check_compiler() {
	which ${CROSS_COMPILE}gcc &> /dev/null ||
		error_exit "Compiler ${CROSS_COMPILE}gcc not found in path."
}

check_xsct() {
	which xsct &> /dev/null ||
		error_exit "Xilinx xcst tool is not in PATH, please source Vitis settings."
}

check_vivado() {
	which vivado &> /dev/null ||
		error_exit "Xilinx Vivado is not in PATH, please source Vivado settings."
}

check_tapasco() {
	[[ -n $TAPASCO_HOME ]] ||
		error_exit "TAPASCO_HOME is not set, please source tapasco-setup.sh from TaPaSCo."
}

check_bootgen() {
	which bootgen &> /dev/null ||
		error_exit "Xilinx bootgen tool is not in PATH, please source Vivado settings."
}

check_image_tools() {
	dusudo which kpartx &> /dev/null ||
		error_exit "Partitioning helper 'kpartx' not found, please install package."
}

check_sdcard() {
	[[ -z $SDCARD || -e $SDCARD ]] ||
		error_exit "SD card device $SDCARD does not exist!"
}

check_chroot() {
	[[ -x /usr/bin/qemu-arm-static && -x /usr/bin/qemu-aarch64-static ]] ||
		error_exit "QEMU user emulation is missing, please install package qemu-user-static."
}

fetch_linux() {
	if [[ ! -d $DIR/linux-xlnx ]]; then
		#handling of xilinx sudden change in name convention
		if [[ $VERSION == 2019.2 ]]; then
			LINUX_VERSION=2019.2.01
		else
			LINUX_VERSION=$VERSION
		fi
		echo "Fetching linux $LINUX_VERSION ..."
		git clone -b xilinx-v$LINUX_VERSION --depth 1 $LINUX_XLNX_URL $DIR/linux-xlnx ||
			return $(error_ret "$LINENO: could not clone linux git")
	else
		echo "$DIR/linux-xlnx already exists, skipping."
	fi
}

fetch_u-boot() {
	if [[ ! -d $DIR/u-boot-xlnx ]]; then
		echo "Fetching u-boot $VERSION ..."
		git clone -b xilinx-v$VERSION --depth 1 $UBOOT_URL $DIR/u-boot-xlnx ||
			return $(error_ret "$LINENO: could not clone u-boot git")
	else
		echo "$DIR/u-boot-xlnx already exists, skipping."
	fi
}

fetch_arm_trusted_firmware() {
	if [[ ! -d $DIR/arm-trusted-firmware ]]; then
		echo "Fetching arm-trusted-firmware ..."
		git clone --depth 1 $ATF_URL $DIR/arm-trusted-firmware ||
			return $(error_ret "$LINENO: could not clone arm-trusted-firmware")
	else
		echo "$DIR/arm-trusted-firmware already exists, skipping."
	fi
}

fetch_rootfs() {
	case $ARCH in
		"arm")
			URL=$ROOTFS_URL
			LOCAL_FILE=$ROOTFS_TAR_GZ
			;;
		"arm64")
			URL=$ROOTFS64_URL
			LOCAL_FILE=$ROOTFS64_TAR_GZ
			;;
	esac
	if [[ ! -f $LOCAL_FILE ]]; then
		echo "Fetching arch linux rootfs..."
		curl -L -s $URL -o $LOCAL_FILE ||
			return $(error_ret "$LINENO: could not fetch $URL")
	else
		echo "$LOCAL_FILE already exists, skipping."
	fi
}

build_u-boot() {
	if [[ ! -e $DIR/u-boot-xlnx/tools/mkimage ]]; then
		echo "Building u-boot $VERSION ..."
		cd $DIR/u-boot-xlnx
		case $BOARD in
			"pynq")
				# based on zybo z7, but requires a few changes
				echo "CONFIG_DEBUG_UART_BASE=0xe0000000" >> $DIR/u-boot-xlnx/configs/$DEFCONFIG
				# modify devicetree
				# change uart1 to uart0
				sed -i 's/uart1/uart0/' $DIR/u-boot-xlnx/arch/arm/dts/zynq-zybo-z7.dts
				# change clock frequency to 50 MHz
				sed -i 's/33333333/50000000/' $DIR/u-boot-xlnx/arch/arm/dts/zynq-zybo-z7.dts
				# set memory size to 512 MB
				sed -i 's/40000000/20000000/' $DIR/u-boot-xlnx/arch/arm/dts/zynq-zybo-z7.dts
				DEVICE_TREE="zynq-zybo-z7"
				;;
			"zedboard")
				DEVICE_TREE="zynq-zed"
				;;
			"zc706")
				DEVICE_TREE="zynq-zc706"
				;;
			"ultra96v2")
				DEVICE_TREE="avnet-ultra96-rev1"
				;;
			"zcu102")
				DEVICE_TREE="zynqmp-zcu102-rev1.1"
				echo "Applying SD3.0 patch to uboot dts for zcu102"
                git apply $SCRIPTDIR/misc/zcu102_sd3_0.uboot.dts.patch || echo "Patch failed. Maybe already applied?"
                #prevent -dirty tag in uboot version
                touch .scmversion
				;;
            "kr260")
                DEVICE_TREE="zynqmp-smk-k26-revA-sck-kr-g-revB"
                ;;
			*)
				return $(error_ret "unknown board: $BOARD")
				;;
		esac
        echo "Building u-boot tools with DEVICE_TREE=$DEVICE_TREE"
		# use common defconfigs introduced with Vivado 2020.1
		if [[ $ARCH == arm ]]; then
			DEFCONFIG=xilinx_zynq_virt_defconfig
		else
			case $BOARD in
				"kr260")
					DEFCONFIG="xilinx_zynqmp_kria_defconfig"
					;;
				*)
					DEFCONFIG="xilinx_zynqmp_virt_defconfig"
					;;
			esac
			#DEFCONFIG="xilinx_zynqmp_virt_defconfig"
		fi
		cp $DIR/u-boot-xlnx/configs/$DEFCONFIG $DIR/u-boot-xlnx/configs/tapasco_defconfig ||
			return $(error_ret "$LINENO: could not copy defconfig $DEFCONFIG")
		DEFCONFIG="tapasco_defconfig"
		if [[ $ARCH == arm ]]; then
			echo "CONFIG_OF_EMBED=y" >> $DIR/u-boot-xlnx/configs/$DEFCONFIG
			echo "# CONFIG_OF_SEPARATE is not set" >> $DIR/u-boot-xlnx/configs/$DEFCONFIG
		fi
		case $BOARD in
			"kr260")
				cat >> $DIR/u-boot-xlnx/configs/$DEFCONFIG <<EOF
CONFIG_USB3320=y
CONFIG_USB5744=y
CONFIG_USB2244=y
CONFIG_ENV_IS_IN_FAT=n
CONFIG_ENV_IS_IN_SPI_FLASH=n
CONFIG_OF_LIST="$DEVICE_TREE"
EOF
				;;
		esac
		make CROSS_COMPILE=$CROSS_COMPILE $DEFCONFIG DEVICE_TREE=$DEVICE_TREE ||
			return $(error_ret "$LINENO: could not make defconfig $DEFCONFIG")
		if [[ $ARCH != arm64 ]]; then
			make CROSS_COMPILE=$CROSS_COMPILE HOSTCFLAGS=$HOSTCFLAGS HOSTLDFLAGS="$HOSTLDFLAGS" DEVICE_TREE=$DEVICE_TREE tools -j $JOBCOUNT ||
				return $(error_ret "$LINENO: could not build u-boot tools")
		fi
	else
		echo "$DIR/u-boot-xlnx/tools/mkimage already exists, skipping."
	fi
}

build_linux() {
	if [[ $ARCH != arm64 ]]; then
		if [[ ! -e $DIR/linux-xlnx/arch/arm/boot/Image ]]; then
			echo "Building linux $VERSION .."
            #create tapasco specific defconfig
			DEFCONFIG=tapasco_zynq_defconfig
            cp $DIR/linux-xlnx/arch/arm/configs/xilinx_zynq_defconfig $DIR/linux-xlnx/arch/arm/configs/$DEFCONFIG ||
				return $(error_ret "$LINENO: could not duplicate zynq defconfig")

            CONFIGFILE="$DIR/linux-xlnx/arch/arm/configs/$DEFCONFIG"
            echo "Adding tapasco specific config options to config file"
            append_if_not_exists 'CONFIG_LOCALVERSION="-tapasco"' $CONFIGFILE
			append_if_not_exists "CONFIG_DEFAULT_HOSTNAME=\"$BOARD\"" $CONFIGFILE

			cd $DIR/linux-xlnx
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm $DEFCONFIG ||
				return $(error_ret "$LINENO: could not make defconfig")
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm -j $JOBCOUNT ||
				return $(error_ret "$LINENO: could not build kernel")
			#works better when doing on host and copying later
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm modules_install INSTALL_MOD_PATH=.
		else
			echo "$DIR/linux-xlnx/arch/arm/boot/Image already exists, skipping."
		fi
	else
		if [[ ! -e $DIR/linux-xlnx/arch/arm64/boot/Image ]]; then
			echo "Building linux $VERSION for arm64.."
            #name for tapasco specific defconfig file
			DEFCONFIG=tapasco_zynqmp_defconfig
            #base tapasco specific config on current version of zynqmp defconfig
            #linux-xlnx v2025.1 and newer no longer have a zynqmp-specific config, use xilinx_defconfig in that case
			cp $DIR/linux-xlnx/arch/arm64/configs/xilinx_zynqmp_defconfig $DIR/linux-xlnx/arch/arm64/configs/$DEFCONFIG ||
				cp $DIR/linux-xlnx/arch/arm64/configs/xilinx_defconfig $DIR/linux-xlnx/arch/arm64/configs/$DEFCONFIG ||
				return $(error_ret "$LINENO: could not duplicate zynqmp defconfig")

			CONFIGFILE="$DIR/linux-xlnx/arch/arm64/configs/$DEFCONFIG"
			echo "Adding tapasco specific config options to config file"
			#add tapasco specific config options to new defconfig file
			append_if_not_exists 'CONFIG_LOCALVERSION="-tapasco"' $CONFIGFILE
			append_if_not_exists "CONFIG_DEFAULT_HOSTNAME=\"$BOARD\"" $CONFIGFILE
			append_if_not_exists 'CONFIG_VFIO=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_VFIO_PLATFORM=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_VFIO_IOMMU_TYPE1=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_ARM_SMMU=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_USB_RTL8152=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_USB_USBNET=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_XATTR=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_ZLIB=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_LZ4=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_LZO=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_XZ=y' $CONFIGFILE
			append_if_not_exists 'CONFIG_SQUASHFS_ZSTD=y' $CONFIGFILE

			#uncomment the following for debugging
			# append_if_not_exists 'CONFIG_FTRACE=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_FUNCTION_TRACER=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_FUNCTION_GRAPH_TRACER=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_DYNAMIC_FTRACE=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_STACK_TRACER=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_BPF=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_BPF_SYSCALL=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_BPF_JIT=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_KPROBES=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_KRETPROBES=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_KALLSYMS=y' $CONFIGFILE
			# append_if_not_exists 'CONFIG_KALLSYMS_ALL=y' $CONFIGFILE

			cd $DIR/linux-xlnx
            case $BOARD in
				"zcu102")
                    echo "Applying patch for zcu102 rev1.1 (SD3.0 and iommu)"
					git apply $SCRIPTDIR/misc/zcu102.dts.patch || echo "Patch failed, maybe already applied?"
					;;
			esac
			if [[ "$VERSION" == "2023.1" || "$VERSION" == "2023.2" ]]; then
				git apply $SCRIPTDIR/misc/linux_6.1_vfio_patch.patch || error_exit "VFIO patch failed!"
			fi
			touch .scmversion #prevent -dirty tag in kernel version
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm64 $DEFCONFIG ||
				return $(error_ret "$LINENO: could not make defconfig")
			make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm64 -j $JOBCOUNT ||
				return $(error_ret "$LINENO: could not build kernel")
            #works better when doing on host and copying later
            make CROSS_COMPILE=$CROSS_COMPILE ARCH=arm64 modules_install INSTALL_MOD_PATH=.
			case $BOARD in
				"ultra96v2")
					cp $DIR/linux-xlnx/arch/arm64/boot/dts/xilinx/avnet-ultra96-rev1.dtb $DIR/devicetree.dtb ||
						return $(error_ret "$LINENO: could not copy device tree")
					;;
				"zcu102")
					cp $DIR/linux-xlnx/arch/arm64/boot/dts/xilinx/zynqmp-zcu102-rev1.1.dtb $DIR/devicetree.dtb ||
						return $(error_ret "$LINENO: could not copy device tree")
					;;
                "kr260")
                    cp $DIR/linux-xlnx/arch/arm64/boot/dts/xilinx/zynqmp-smk-k26-revA-sck-kr-g-revB.dtb $DIR/devicetree.dtb ||
                        return $(error_ret "$LINENO: could not copy device tree")
                    ;;
			esac
		else
			echo "$DIR/linux-xlnx/arch/arm64/boot/Image already exists, skipping."
		fi
	fi
}

build_ssbl() {
	if [[ ! -e $DIR/u-boot-xlnx/u-boot ]]; then
		echo "Building second stage boot loader ..."
		cd $DIR/u-boot-xlnx
		if [[ $ARCH != arm64 ]]; then
			DTC=$DIR/linux-xlnx/scripts/dtc/dtc
			make CROSS_COMPILE=$CROSS_COMPILE DTC=$DTC HOSTCFLAGS=$HOSTCFLAGS HOSTLDFLAGS="$HOSTLDFLAGS" u-boot -j $JOBCOUNT ||
				return $(error_ret "$LINENO: could not build u-boot")
		else
            if [[ -z "${DEVICE_TREE}" ]]; then
                echo "Env variable DEVICE_TREE not set"
                echo "Setting DEVICE_TREE based on $BOARD"
                case $BOARD in
                    "pynq")
                        DEVICE_TREE="zynq-zybo-z7"
                        ;;
                    "zedboard")
                        DEVICE_TREE="zynq-zed"
                        ;;
                    "zc706")
                        DEVICE_TREE="zynq-zc706"
                        ;;
                    "ultra96v2")
                        DEVICE_TREE="avnet-ultra96-rev1"
                        ;;
                    "zcu102")
                        DEVICE_TREE="zynqmp-zcu102-rev1.1"
                        ;;
                    "kr260")
                        DEVICE_TREE="zynqmp-smk-k26-revA-sck-kr-g-revB"
                        ;;
                    *)
                        return $(error_ret "unknown board: $BOARD")
				        ;;
		        esac
            else
			    echo "DEVICE_TREE env variable already set to ${DEVICE_TREE}"
            fi
            echo "Building u-boot ssbl for DEVICE_TREE=$DEVICE_TREE"
            export DEVICE_TREE=$DEVICE_TREE
			make CROSS_COMPILE=$CROSS_COMPILE -j $JOBCOUNT ||
				return $(error_ret "$LINENO: could not build u-boot")
		fi
	else
		echo "$DIR/u-boot-xlnx/u-boot already exists, skipping."
	fi

	if [[ ! -f $DIR/boot.scr && -e $SCRIPTDIR/bootscr/boot-$BOARD.txt ]]; then
		$DIR/u-boot-xlnx/tools/mkimage -A arm -T script -O linux -d $SCRIPTDIR/bootscr/boot-$BOARD.txt $DIR/boot.scr
	fi

	if [[ $ARCH != arm64 ]]; then
		cp $DIR/u-boot-xlnx/u-boot $DIR/u-boot-xlnx/u-boot.elf ||
			return $(error_ret "$LINENO: could not copy to $DIR/u-boot-xlnx/u-boot.elf failed")
	fi

    unset DEVICE_TREE
}

build_uimage() {
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

build_fsbl() {
	if [[ ! -f $DIR/fsbl/executable.elf ]]; then
		mkdir -p $DIR/fsbl || return $(error_ret "$LINENO: could not create $DIR/fsbl")
		if [[ $ARCH != arm64 ]]; then
			pushd $DIR/fsbl > /dev/null &&
				cat > project.tcl << EOF
package require json

set platform_file [open "\$env(TAPASCO_HOME_TCL)/platform/$BOARD/platform.json" r]
set json [read \$platform_file]
close \$platform_file
set platform [::json::json2dict \$json]

source "\$env(TAPASCO_HOME_TCL)/common/common.tcl"
source "\$env(TAPASCO_HOME_TCL)/platform/common/platform.tcl"
source "\$env(TAPASCO_HOME_TCL)/platform/$BOARD/$BOARD.tcl"
create_project $BOARD $BOARD -part [dict get \$platform "Part"] -force
set board_part ""
if {[dict exists \$platform "BoardPart"]} {
	set parts [get_board_parts -filter [format {NAME =~ "%s*"} [dict get \$platform "BoardPart"]]]
	set board_part [lindex \$parts [expr [llength \$parts] - 1]]
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

set platform_file [open "\$env(TAPASCO_HOME_TCL)/platform/$BOARD/platform.json" r]
set json [read \$platform_file]
close \$platform_file
set platform [::json::json2dict \$json]

source "\$env(TAPASCO_HOME_TCL)/common/common.tcl"
source "\$env(TAPASCO_HOME_TCL)/platform/common/platform.tcl"
source "\$env(TAPASCO_HOME_TCL)/platform/$BOARD/$BOARD.tcl"

create_project -force $BOARD $BOARD -part [dict get \$platform "Part"]
set board_part ""
if {[dict exists \$platform "BoardPart"]} {
	set parts [get_board_parts -filter [format {NAME =~ "%s*"} [dict get \$platform "BoardPart"]]]
	set board_part [lindex \$parts [expr [llength \$parts] - 1]]
	set_property board_part \$board_part [current_project]
}
if {[dict exists \$platform "BoardConnections"]} {
    set board_conns [dict get \$platform "BoardConnections"]
    set_property board_connections \$board_conns [current_project]
}
create_bd_design -quiet "system"
set board_preset {}
if {[dict exists \$platform "BoardPreset"]} {
	set board_preset [dict get \$platform "BoardPreset"]
}
set ps [tapasco::ip::create_ultra_ps "zynqmp" \$board_preset 100]
set_property -dict [list \
    CONFIG.PSU__FPGA_PL1_ENABLE {1} \
    CONFIG.PSU__USE__S_AXI_GP0 {1}  \
    CONFIG.PSU__USE__S_AXI_GP2 {0}  \
    CONFIG.PSU__USE__S_AXI_GP4 {1}  \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ {10} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__USE__IRQ1 {1} \
    CONFIG.PSU__HIGH_ADDRESS__ENABLE {1} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {1} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} ] \$ps
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" } \$ps
set clk [lindex [get_bd_pins -of_objects \$ps -filter { TYPE == clk && DIR == O }] 0]
connect_bd_net \$clk [get_bd_pins -of_objects \$ps -filter { TYPE == clk && DIR == I}]
validate_bd_design
make_wrapper -files [get_files $DIR/fsbl/$BOARD/$BOARD.srcs/sources_1/bd/system/system.bd] -top -import
update_compile_order -fileset sources_1
generate_target all [get_files $DIR/fsbl/$BOARD/$BOARD.srcs/sources_1/bd/system/system.bd]
write_hw_platform -fixed -force  -file $BOARD.xsa
puts "XSA in $BOARD.xsa, done"
exit
EOF
			cat > hsi.tcl << EOF
hsi::open_hw_design $BOARD.xsa
set fsbl_design [hsi::create_sw_design -proc psu_cortexa53_0 -os standalone -app zynqmp_fsbl -name fsbl]
common::set_property APP_COMPILER "aarch64-none-elf-gcc" \$fsbl_design
common::set_property -name APP_COMPILER_FLAGS -value "-DRSA_SUPPORT -DFSBL_DEBUG_DETAILED" -objects \$fsbl_design
hsi::add_library libmetal
hsi::generate_app -dir . -compile
EOF
		fi

		vivado -nolog -nojournal -notrace -mode batch -source project.tcl ||
			return $(error_ret "$LINENO: Vivado could not build project")
		xsct hsi.tcl ||
			return $(error_ret "$LINENO: hsi could not build FSBL")
		popd &> /dev/null
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
		popd &> /dev/null
	else
		echo "$BOARD/pmufw/executable.elf already exists, skipping."
	fi
}

build_arm_trusted_firmware() {
	if [[ ! -f $DIR/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf ]]; then
		echo "Building Arm Trusted Firmware for ZynqMP ..."
		cd $DIR/arm-trusted-firmware
		case $BOARD in
            "kr260")
                ATF_USE_UART="ZYNQMP_CONSOLE=cadence1"
                ;;
            *)
                ATF_USE_UART=""
                ;;
		esac
		if [[ "$VERSION" == "2023.1" || "$VERSION" == "2023.2" ]]; then
			make CROSS_COMPILE=aarch64-none-elf- PLAT=zynqmp DEBUG=0 bl31 $ATF_USE_UART
		else
			make CROSS_COMPILE=$CROSS_COMPILE PLAT=zynqmp RESET_TO_BL31=1 $ATF_USE_UART
		fi
	else
		echo "$BOARD/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf already exists, skipping."
	fi
}

build_bootbin() {
	if [[ ! -f $DIR/BOOT.BIN ]]; then
		echo "Building BOOT.BIN ..."
		if [[ $ARCH == arm64 ]]; then
			# set brdc_inner bit of the lpd_apu register in the LPD_SLCR module for VFIO/SMMU support
			cat > $DIR/regs.init << EOF
.set. 0xFF41A040 = 0x3;
EOF

			cat > $DIR/bootimage.bif << EOF
                boot_image : {
                    [init] $DIR/regs.init
                    [bootloader,destination_cpu=a53-0] $DIR/fsbl/executable.elf
                    [pmufw_image] $DIR/pmufw/executable.elf
                    [destination_cpu=a53-0, exception_level=el-3,trustzone] $DIR/arm-trusted-firmware/build/zynqmp/release/bl31/bl31.elf
                    [destination_cpu=a53-0, exception_level=el-2] $DIR/u-boot-xlnx/u-boot.elf
                }
EOF
			bootgen -arch zynqmp -image $DIR/bootimage.bif -w on -o $DIR/BOOT.BIN ||
				return $(error_ret "$LINENO: could not generate BOOT.bin")
		else
			cat > $DIR/bootimage.bif << EOF
                boot_image : {
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

build_devtree() {
	echo "Building devicetree ..."
	case $BOARD in
		"pynq")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
				cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
				curl -L -s $ARTYZ7_DTS_URL | sed 's/#include/\/include\//' > $DIR/devicetree.dts
			;;
		"zedboard")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
				cat $SCRIPTDIR/misc/zynq-7000.dtsi.patch | patch $DIR/zynq-7000.dtsi &&
				cp $DIR/linux-xlnx/arch/arm/boot/dts/skeleton.dtsi $DIR/ &&
				cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zed.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts
			;;
		"zc706")
			cp $DIR/linux-xlnx/arch/arm/boot/dts/zynq-7000.dtsi $DIR/ &&
				cat $DIR/linux-xlnx/arch/arm/boot/dts/zynq-zc706.dts | sed 's/#include/\/include\//' > $DIR/devicetree.dts
			;;
		"ultra96v2")
			#work around: Re-compile dts from dtb generated by linux-build and add tapasco related interrupts
			$DIR/linux-xlnx/scripts/dtc/dtc -I dtb -O dts -o $DIR/devicetree.dts $DIR/devicetree.dtb
			echo "/include/ \"$SCRIPTDIR/misc/tapasco_zynqmp_reserve_cma.dtsi\"" >> $DIR/devicetree.dts
			;;
		"zcu102")
			$DIR/linux-xlnx/scripts/dtc/dtc -I dtb -O dts -o $DIR/devicetree.dts $DIR/devicetree.dtb
			echo "/include/ \"$SCRIPTDIR/misc/tapasco_zynqmp_reserve_cma.dtsi\"" >> $DIR/devicetree.dts
			;;
        "kr260")
			$DIR/linux-xlnx/scripts/dtc/dtc -I dtb -O dts -o $DIR/devicetree.dts $DIR/devicetree.dtb
			;;
	esac
	echo >> $DIR/devicetree.dts
	if [[ $ARCH == arm64 ]]; then
		echo "/include/ \"$SCRIPTDIR/misc/tapasco_zynqmp.dtsi\"" >> $DIR/devicetree.dts

		# re-add label that was lost during compilation, so that we can reference it in dtsi
		sed -i 's/iommu@fd800000/smmu: iommu@fd800000/' $DIR/devicetree.dts
		# enable referencing of interrupt controller instead of hardcoded phandle
		sed -i 's/interrupt-controller@f9010000/gic: interrupt-controller@f9010000/' $DIR/devicetree.dts
	else
		echo "/include/ \"$SCRIPTDIR/misc/tapasco.dtsi\"" >> $DIR/devicetree.dts

		sed -i 's/interrupt-controller@f8f01000/intc: interrupt-controller@f8f01000/' $DIR/devicetree.dts
	fi
	$DIR/linux-xlnx/scripts/dtc/dtc -I dts -O dtb -o $DIR/devicetree.dtb $DIR/devicetree.dts ||
		return $(error_ret "$LINENO: could not build devicetree.dtb")
	echo "$DIR/devicetree.dtb ready."
}

build_output_image() {
	# size of image (in MiB)
	IMGSIZE=${1:-7534}
	# default root size: MAX - 358 MiB (converted to 512B sectors)
	ROOTSZ=${2:-$(((IMGSIZE - 358) * 1024 * 1024 / 512))}
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
		LD=$(basename $LOOPDEV)
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

prepare_sd() {
	echo "dd'ing $OUTPUT_IMAGE to $SDCARD, this will take a while ..."
	dusudo dd if=$OUTPUT_IMAGE of=$SDCARD bs=10M ||
		return $(error_ret "$LINENO: could not dd $OUTPUT_IMAGE to $SDCARD")
	echo "$SDCARD ready."
}

copy_files_to_boot() {
	DEV=${1:-${SDCARD}1}
	TO="$DIR/$(basename $DEV)"
	echo "Preparing BOOT partition $TO ..."
	mkdir -p $TO || return $(error_ret "$LINENO: could not create $TO")
	dusudo mount $DEV $TO || return $(error_ret "$LINENO: could not mount $DEV -> $TO")
	echo "Copying $DIR/BOOT.BIN to $TO ..."
	dusudo cp $DIR/BOOT.BIN $TO || echo >&2 "$LINENO: WARNING: could not copy BOOT.BIN"
	if [[ $ARCH == arm64 ]]; then
		echo "Copying $DIR/linux-xlnx/arch/arm64/boot/Image to $TO ..."
		dusudo cp $DIR/linux-xlnx/arch/arm64/boot/Image $TO ||
			echo >&2 "$LINENO: WARNING: could not copy Image"
		echo "Copying $DIR/devicetree.dtb to $TO/system.dtb ..."
		dusudo cp $DIR/devicetree.dtb $TO/system.dtb || echo >&2 "$LINENO: WARNING: could not copy devicetree"
		if [[ -f uenv/uEnv-$BOARD.txt && ! -f $DIR/boot.scr ]]; then
			echo "Copying uenv/uEnv-$BOARD.txt to $TO/uEnv.txt ..."
			dusudo cp uenv/uEnv-$BOARD.txt $TO/uEnv.txt ||
				echo >&2 "$LINENO: WARNING: could not copy uEnv.txt"
		fi
	else
		echo "Copying $DIR/linux-xlnx/arch/arm/boot/uImage to $TO ..."
		dusudo cp $DIR/linux-xlnx/arch/arm/boot/uImage $TO ||
			echo >&2 "$LINENO: WARNING: could not copy uImage"
		echo "Copying uenv/uEnv-$BOARD.txt to $TO/uEnv.txt ..."
		dusudo cp uenv/uEnv-$BOARD.txt $TO/uEnv.txt ||
			echo >&2 "$LINENO: WARNING: could not copy uEnv.txt"
		echo "Copying $DIR/devicetree.dtb to $TO ..."
		dusudo cp $DIR/devicetree.dtb $TO || echo >&2 "$LINENO: WARNING: could not copy devicetree"
	fi
	if [[ -f $DIR/boot.scr ]]; then
		echo "Copying $DIR/boot.scr to $TO/boot.scr ..."
		dusudo cp $DIR/boot.scr $TO/boot.scr || echo >&2 "$LINENO: WARNING: could not copy boot.scr"
	fi
	dusudo umount $TO
	rmdir $TO 2> /dev/null &&
		echo "Boot partition ready."
}

copy_files_to_root() {
	case $ARCH in
		"arm")
			LOCAL_FILE=$ROOTFS_TAR_GZ
			;;
		"arm64")
			LOCAL_FILE=$ROOTFS64_TAR_GZ
			;;
	esac
	DEV=${1:-${SDCARD}2}
	TO="$DIR/$(basename $DEV)"
	mkdir -p $TO || return $(error_ret "$LINENO: could not create $TO")
	dusudo mount $DEV $TO || #remove onoacl on e.g. debian
		return $(error_ret "$LINENO: could not mount $DEV -> $TO")
	echo "Extracting rootfs"
	dusudo sh -c "tar -xpf $LOCAL_FILE -C $TO" ||
		echo >&2 "$LINENO: WARNING: could not extract rootfs"
	echo "Setting hostname to $BOARD ... "
	dusudo sh -c "echo $BOARD > $TO/etc/hostname" ||
		echo >&2 "$LINENO: WARNING: could not set hostname"
	echo "Installing linux headers ..."
	dusudo sh -c "cp -r $DIR/linux-xlnx $TO/usr/src/linux-headers-$(make -C $DIR/linux-xlnx kernelrelease -s)" ||
		echo >&2 "$LINENO: WARNING: could not copy linux-xlnx"
	echo "Preparing chroot environment"
	dusudo sh -c "cp /usr/bin/qemu-arm-static $TO/usr/bin/"
	dusudo sh -c "cp /usr/bin/qemu-aarch64-static $TO/usr/bin/"
	dusudo sh -c "mount --bind /dev $TO/dev/"
	dusudo sh -c "chroot $TO << EOF
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 1.1.1.1' >> /etc/resolv.conf
apt-get update
apt-get -y upgrade
# runtime dependencies (without linux-headers)
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential python3 cmake libelf-dev libncurses-dev git rpm
# additional tools
apt-get install -y curl flex bison vim-tiny sudo iproute2 ssh kmod ifupdown net-tools jitterentropy-rngd haveged libssl-dev bc rsync protobuf-compiler fdisk
systemctl enable ssh
systemctl enable getty@ttyPS0.service
useradd -G sudo -m -s /bin/bash tapasco
echo 'root:root' | chpasswd
echo 'tapasco:tapasco' | chpasswd
echo 'set nocompatible' > /root/.vimrc
echo 'set nocompatible' > /home/tapasco/.vimrc
# setup network
echo 'auto eth0' >> /etc/network/interfaces
echo 'iface eth0 inet dhcp' >> /etc/network/interfaces

# prepare header files
cd /usr/src/linux-headers-*-tapasco*/
make clean
make scripts
# recompile scripts needed for custom kernel modules
make modules_prepare
make headers_install
# install the previously compiled kernel modules
mkdir -p /lib/modules
cp -r lib/modules/* /lib/modules
cd /lib/modules/*-tapasco*
# remove broken links
rm -rf build source
#
ln -s /usr/src/linux-headers-*-tapasco*/ build

git clone https://github.com/esa-tu-darmstadt/tapasco.git /home/tapasco/tapasco
chown -R tapasco /home/tapasco/tapasco
echo '' > /etc/resolv.conf
EOF"
	dusudo rm $TO/usr/bin/qemu-*
	dusudo cp $SCRIPTDIR/misc/resizefs $TO/home/tapasco/
	dusudo umount $TO/dev
	dusudo umount $TO
	rmdir $TO 2> /dev/null &&
		echo "RootFS partition ready."
}

################################################################################
################################################################################

if [ -z ${CROSS_COMPILE+x} ]; then
	if [[ $BOARD == ultra96v2 ]] || [[ $BOARD == zcu102 ]] || [[ $BOARD == kr260 ]]; then
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
check_board
check_compiler
check_xsct
check_vivado
check_tapasco
check_chroot
check_sdcard
if [ "$OMIT_ROOT" = false ] ; then
    read -p "Enter sudo password: " -s SUDOPW
    [[ -n $SUDOPW ]] || error_exit "sudo password may not be empty"
    dusudo true || error_exit "sudo password seems to be wrong?"
fi
if [ "$OMIT_ROOT" = false ] ; then
	check_image_tools
fi
mkdir -p $LOGDIR 2> /dev/null
printf "\nAnd so it begins ...\n"
################################################################################
echo "Fetching Linux kernel, U-Boot sources, rootfs and additional tools ..."
fetch_linux &> $FETCH_LINUX_LOG &
FETCH_LINUX_OK=$!
fetch_u-boot &> $FETCH_UBOOT_LOG &
FETCH_UBOOT_OK=$!
fetch_rootfs &> $FETCH_ROOTFS_LOG &
FETCH_ARCH_LINUX_OK=$!
if [[ $ARCH == arm64 ]]; then
	fetch_arm_trusted_firmware &> $FETCH_ARM_TRUSTED_FIRMWARE_LOG &
	FETCH_ARM_TRUSTED_FIRMWARE_OK=$!
fi

wait $FETCH_LINUX_OK || error_exit "Fetching Linux failed, check log: $FETCH_LINUX_LOG"
wait $FETCH_UBOOT_OK || error_exit "Fetching U-Boot failed, check logs: $FETCH_UBOOT_LOG"
wait $FETCH_ARCH_LINUX_OK || error_exit "Fetching Arch Linux Rootfs failed, check log: $FETCH_ARCH_LINUX_LOG"
if [[ $ARCH == arm64 ]]; then
	wait $FETCH_ARM_TRUSTED_FIRMWARE_OK || error_exit "Fetching ARM Trusted Firmware failed, check log: $FETCH_ARM_TRUSTED_FIRMWARE_LOG"
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
if [[ $ARCH == arm64 ]]; then
	echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and Arm Trusted Firmware (output in $BUILD_ARM_TRUSTED_FIRMWARE_LOG) ... "
	build_arm_trusted_firmware &> $BUILD_ARM_TRUSTED_FIRMWARE_LOG &
	BUILD_ARM_TRUSTED_FIRMWARE_OK=$!
	wait $BUILD_ARM_TRUSTED_FIRMWARE_OK || error_exit "Building Arm Trusted Firmware failed, check log: $ARM_TRUSTED_FIRMWARE_LOG"
else
	echo "Building U-Boot SSBL (output in $BUILD_SSBL_LOG) and uImage (output in $BUILD_UIMAGE_LOG) ..."
	build_uimage &> $BUILD_UIMAGE_LOG &
	BUILD_UIMAGE_OK=$!
	wait $BUILD_UIMAGE_OK || error_exit "Building uImage failed, check log: $BUILD_UIMAGE_LOG"
fi

build_ssbl &> $BUILD_SSBL_LOG &
BUILD_SSBL_OK=$!
wait $BUILD_SSBL_OK || error_exit "Building U-Boot SSBL failed, check log: $BUILD_SSBL_LOG"

################################################################################
echo "Build FSBL (output in $BUILD_FSBL_LOG) ..."
build_fsbl &> $BUILD_FSBL_LOG &
BUILD_FSBL_OK=$!
wait $BUILD_FSBL_OK || error_exit "Building FSBL failed, check log: $BUILD_FSBL_LOG"

if [[ $ARCH == arm64 ]]; then
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
################################################################################

if [ "$OMIT_ROOT" = false ] ; then

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

fi

case $BOARD in
	"kr260")
		echo ""
		echo "IMPORTANT: Before using your Kria board with TaPaSCo, please flash"
		echo "$DIR/BOOT.BIN"
		echo "to the active QSPI boot image slot using the Boot Image Recovery Tool."
		echo "To run the tool, hold the FWUEN button of the carrier board while"
		echo "powering it on and follow the instructions printed to UART1."
		;;
esac
