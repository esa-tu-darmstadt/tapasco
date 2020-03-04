The Task Parallel System Composer (TaPaSCo)
===========================================
![Tapasco logo](misc/icon/tapasco_icon.png)

Master Branch Status: [![pipeline status](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/badges/master/pipeline.svg)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/commits/master)
Dev Branch Status: [![pipeline status](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/badges/develop/pipeline.svg)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/commits/develop)

System Requirements
-------------------
TaPaSCo is known to work in this environment:

*   Intel x86_64 arch
*   Linux kernel 4.4+
*   Fedora 26+, Ubuntu 16.04+
*   Fedora 24/25 does not support debug mode due to GCC bug
*   Bash Shell 4.2.x+

Other setups likely work as well, but are untested.

Prerequisites for Toolflow
-------------
To use TaPaSCo, you'll need working installations of

*   Vivado Design Suite 2017.4 or newer
*   Java SDK 8 - 11
*   git
*   python
*   GCC newer than 5.x.x for C++11 support
*   *OPTIONAL:* libncurses for the tapasco-debug application
*   *OPTIONAL:* Local Installation of gradle 5.0+, if you do not want to use the included wrapper.

If you want to use the High-Level Synthesis flow for generating custom IP
cores, you will also need:

*   Vivado HLS 2017.4+

Check that at least the following are in your `$PATH`:

*   `vivado` - If not source `path/to/vivado/settings64.sh`
*   `git`
*   `bash`
*   \[`vivado_hls`\] - Since Vivado 2018.1 this is included in `vivado`

When using *Ubuntu*, ensure that the following packages are installed:

* unzip
* zip
* git
* findutils
* curl
* default-jdk

```
apt-get -y install unzip git zip findutils curl default-jdk
```

When using *Fedora*, ensure that the following packages are installed:

* which
* java-openjdk
* findutils

```
dnf -y install which java-openjdk findutils
```


TaPaSCo-Toolflow Setup
----------------------

Using the prebuilt packages, the setup of TaPaSCo is very easy:

1.  Create or open a folder, which you would like to use as your TaPaSCo workspace.
    Within this folder, run the TaPaSCo-Initialization-Script which is located in
    `/opt/tapasco/tapasco-init-toolflow.sh`. This will setup your current folder as `TAPASCO_WORK_DIR`.
    It will also create the file `tapasco-setup.sh` within your current directory. 
2.	Source `tapasco-setup.sh`.

If you want to use a specific (pre-release) version or branch, you can do the following:

1.  Clone TaPaSCo: `git clone https://github.com/esa-tu-darmstadt/tapasco.git`
2.  _Optionally_ Checkout a corresponding branch: `git checkout <BRANCH>`
3.  Create or open a folder, which you would like to use as your TaPaSCo workspace.
    Within this folder, run the TaPaSCo-Initialization-Script `tapasco-init.sh` which is located in the root-folder 
    of your cloned repo. This will setup your current folder as `TAPASCO_WORK_DIR`.
    It will also create the file `tapasco-setup.sh` within your workdir.
4.  Source `tapasco-setup.sh` to setup the TaPaSCo-Environment.
5.  Build the TaPaSCo-Toolflow using `tapasco-build-toolflow`.

Whenever you want to use TaPaSCo in the future, just source the corresponding workspace using the `tapasco-setup.sh`.
This also allows you to have multiple independent TaPaSCo-Workspaces.

Prerequisites for the Runtime
-------------

*Ubuntu*:
```
apt-get -y install build-essential linux-headers-generic python cmake libelf-dev libncurses-dev git rpm
```

*Fedora*:
```
dnf -y install kernel-devel make gcc gcc-c++ elfutils-libelf-devel cmake ncurses-devel python libatomic git rpm-build
```

TaPaSCo-Runtime Setup
---------------------

If you want to use a specific (pre-release) version or branch, you can do the following:

1.  Clone TaPaSCo: `git clone https://github.com/esa-tu-darmstadt/tapasco.git`
2.  _Optionally_ Checkout a corresponding branch: `git checkout <BRANCH>`
3.  Create or open a folder, which you would like to use as your TaPaSCo workspace.
    Within this folder, run the TaPaSCo-Initialization-Script `tapasco-init.sh` which is located in the root-folder 
    of your cloned repo. This will setup your current folder as `TAPASCO_WORK_DIR`.
    It will also create the file `tapasco-setup.sh` within your workdir.
4.  Source `tapasco-setup.sh` to setup the TaPaSCo-Environment.
5.  Build the TaPaSCo-Toolflow using `tapasco-build-libs`.

All of this is not necessary when using the prebuilt packages. In that case, the corresponding libraries and files are installed as usual for your OS.

Getting Started - Build a TaPaSCo design
----------------------------------------
1.  Import your kernels
    *   HDL flow: `tapasco import path/to/ZIP as <ID> -p <PLATFORM>` will import the corresponding ZIP file as a new HDL-based core. The Kernel-ID is set from <ID> and the optional flag `-p <PLATFORM>` determines for which platform the kernel will be available. If it is omitted, it will be made available for all platforms which may take a lot of time.
    *   HLS flow: `tapasco hls <KERNEL> -p <PLATFORM>` will perform hls according to the `kernel.json`. The resulting HLS-based core will be made available for the platform given by `-p <PLATFORM>`. Again, `-p` can be omitted. HLS-Kernels are generally located in `$TAPASCO_WORKDIR/kernel`. If you want to add kernels you can create either symlink or copy them into the folder. Additionally, the folder can be temporarily changed using the optional `--kernelDir path/to/kernels` flag like this: `tapasco --kernelDir path/to/kernels hls <KERNEL> -p <PLATFORM>`
2.  Create a composition: `tapasco compose [<KERNEL> x <COUNT>] @ <NUM> MHz -p <PLATFORM>`
3.  Load the bitstream: `tapasco-load-bitstream <BITSTREAM>`
4.  Implement your host software
    *   C API
    *   C++ API

You can get more information about commands with `tapasco --help` and the corresponding subpages with `tapasco --help <TOPIC>`


Getting Started - Build a Software-Interface
--------------------------------------------
1.  Design your Accelerator using HLS/HDL according to the previous section.
2.  Load your bitstream: `tapasco-load-bitstream my-design.bit --reload-driver`. To do this, you have to source `vivado` and `tapasco-setup.sh`.
3.  Write a C/C++ executable that interfaces with your design accordingly. To get a better understanding of this, you might want to refer to the collection of examples and the corresponding README which is located in `$TAPASCO_HOME/runtime/examples`
4.  Build and Compile your Software.



Acknowledgements
----------------
TaPaSCo is based on [ThreadPoolComposer][1], which was developed by us as part
of the [REPARA project][2], a _Framework Seven (FP7) funded project by the
European Union_.

We would also like to thank [Bluespec, Inc.][3] for making their _Bluespec
SystemVerilog (BSV)_ tools available to us and their permission to distribute
the Verilog code generated by the _Bluespec Compiler (bsc)_.

[1]: https://git.esa.informatik.tu-darmstadt.de/REPARA/threadpoolcomposer.git
[2]: http://repara-project.eu/
[3]: http://bluespec.com/

Publications
------------

A List of publications about TaPaSCo or TaPaSCo-related research can be found [here](https://github.com/esa-tu-darmstadt/tapasco/wiki/Publications).

If you want to cite TaPaSCo, please use the following information:

[Korinth2019] Korinth, Jens, Jaco Hofmann, Carsten Heinz, and Andreas Koch. 2019. **The
Tapasco Open-Source Toolflow for the Automated Composition of Task-Based
Parallel Reconfigurable Computing Systems.** In *International Symposium
on Applied Reconfigurable Computing (Arc)*.

Releases
----------------

We provided pre-compiled packages for many popular Linux distributions. All packages are build for the x86_64 variant.

### Ubuntu 16.04
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_16_04)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_16_04_debug)
[Runtime (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_16_04)
[Runtime Debug (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_16_04_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco_2019-10_amd64.deb?job=build_scala_tapasco_ubuntu_16_04)

### Ubuntu 18.04
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_18_04)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_18_04_debug)
[Runtime (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_18_04)
[Runtime Debug (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_18_04_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco_2019-10_amd64.deb?job=build_scala_tapasco_ubuntu_18_04)

### Ubuntu 18.10
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_18_10)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_18_10_debug)
[Runtime (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_18_10)
[Runtime Debug (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_18_10_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco_2019-10_amd64.deb?job=build_scala_tapasco_ubuntu_18_10)

### Ubuntu 19.04
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_19_04)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_ubuntu_19_04_debug)
[Runtime (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_19_04)
[Runtime Debug (DEB)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.deb?job=build_tapasco_ubuntu_19_04_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco_2019-10_amd64.deb?job=build_scala_tapasco_ubuntu_19_04)

### Fedora 27
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_27)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_27_debug)
[Runtime (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_27)
[Runtime Debug (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_27_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco-2019-10.x86_64.rpm?job=build_scala_tapasco_fedora_27)

### Fedora 28
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_28)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_28_debug)
[Runtime (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_28)
[Runtime Debug (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_28_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco-2019-10.x86_64.rpm?job=build_scala_tapasco_fedora_28)

### Fedora 29
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_29)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_29_debug)
[Runtime (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_29)
[Runtime Debug (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_29_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco-2019-10.x86_64.rpm?job=build_scala_tapasco_fedora_29)

### Fedora 30
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_30)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_30_debug)
[Runtime (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_30)
[Runtime Debug (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_30_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco-2019-10.x86_64.rpm?job=build_scala_tapasco_fedora_30)

### Fedora 31
[Kernel Driver](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_31)
[Kernel Driver Debug](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/runtime/kernel/tlkm.ko?job=build_kernel_fedora_31_debug)
[Runtime (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_31)
[Runtime Debug (RPM)](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/build/tapasco-2019.10.0-Linux.rpm?job=build_tapasco_fedora_31_debug)
[Toolflow](https://git.esa.informatik.tu-darmstadt.de/tapasco/tapasco/-/jobs/artifacts/master/raw/toolflow/scala/build/distributions/tapasco-2019-10.x86_64.rpm?job=build_scala_tapasco_fedora_31)
