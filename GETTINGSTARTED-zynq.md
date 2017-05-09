ThreadPoolComposer -- Getting Started Part 2 (Zynq)
===================================================
This is the second part of the TPC tutorial, concerned with the Zynq platforms
only. In this part we will load the bitstream generated in Part 1 to the FPGA
and compile and execute the demo application on the board.
We will use a zedboard in the following, but the basic operation of the ZC706
is identical, so you can use it for the ZC706 as well.

Preparing the system
--------------------
By default, the TPC linux image has two users:

1. `root` (passwd: `root`)
2. `tpc` (passwd: `tpctpc`)

Obviously this is an extremely insecure setup and should be changed immediately.
Login as `root`, then use the `passwd` program to change the root password.
Repeat for user `tpc`.

The user `tpc` is `sudoer`, i.e., you can use the `sudo` program to temporarily
gain root privileges. This is sufficient for TPC, but feel free to configure
the system in any way you like.

Preparing the TPC libaries and driver
-------------------------------------
The ThreadPoolComposer software stack consists of three layers:

1. TPC(++) API (`libtpc.so` / `libtpc.a`)
2. Platform API (`libplatform.so` / `libplatform.a`)
3. Device Driver (`tpc-platform-zynq.ko`)

When you are using TPC, you will only need to concern yourself with TPC API,
the other layers will be hidden from the application point of view.
Nevertheless, they need to be available to build and run the application.

To simplify the building of the libraries, there is a script in `$TPC_HOME/bin`
called `tpc-build-libs`. It will compile all three layers:

        [tpc@zed] ~ tpc-build-libs

This will build the libraries for the zedboard in Release mode, you should see
several lines of status logs, e.g.:

        Building release mode libraries, pass 'debug' as first argument to build debug libs...
        KCPPFLAGS="-DNDEBUG -O3" make -C /home/tpc/linux-xlnx M=/home/tpc/threadpoolcomposer/2016.03/platform/zynq/module modules
        make[1]: Entering directory '/home/tpc/linux-xlnx'
          CC [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/zynq_module.o
          CC [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/zynq_device.o
          CC [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/zynq_dmamgmt.o
          CC [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/zynq_irq.o
          CC [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/zynq_ioctl.o
          LD [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/tpc-platform-zynq.o
          Building modules, stage 2.
          MODPOST 1 modules
          CC      /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/tpc-platform-zynq.mod.o
          LD [M]  /home/tpc/threadpoolcomposer/2016.03/platform/zynq/module/tpc-platform-zynq.ko
        make[1]: Leaving directory '/home/tpc/linux-xlnx'
        ...

TPC is now ready! By default, the script will build the libraries in release 
mode, but you can switch to debug mode easily:

        [tpc@zed] ~ tpc-build-libs --mode debug

Logging features are enabled in debug mode only, see the Debugging chapter at
the end of this document. See also `tpc-build-libs --help` for more info.

Loading bitstreams
------------------
The next step is to copy the bitstreams (.bit files) we have prepared in Part 1
to the device.  Once you have copied the .bit file to the board (e.g., via
`scp`), you need to load it to the FPGA, then load the driver.

For convenience, there is a script called `tpc-load-bitstream` in `$TPC_HOME/bin`
that simplifies this process, which can be called like this:

        [tpc@zed] ~ tpc-load-bitstream --reload-driver <PATH TO .bit FILE>

It will ask for the `sudo` password of the user `tpc` (loading the bitstream
and driver requires root privilege). On the zedboard there is a blue status LED
(left of the OLED display) that indicates whether or not a valid bitstream is
configured in the FPGA. 

If everything goes well, you should see some log messages similar to this:

        ~/threadpoolcomposer/2016.03/platform/zynq/module ~/threadpoolcomposer/2016.03
        [sudo] password for tpc: 
        Loading bitstream /home/tpc/basic_test.bd.bit ...
        Done!
        Loading kernel module ...
        ~/threadpoolcomposer/2016.03
        Done.

On the zedboard there is a bright blue LED (left of the OLED display) that will
turn on when a valid bitstream has been configured in the FPGA. After running
this script it should turn on.

**Warning:** Do not load the device driver unless a valid TPC bitstream is
loaded! The system will crash and require a cold reboot. Unfortunately, there is
no safe way to probe the hardware in the reconfigurable fabric; the CPU will
attempt to read in the memory section where the FPGA is mapped and cause a bus
stall if no device in the fabric answers.

Compiling TPC(++) API programs
------------------------------
Continuing the example from Part 1, we will now compile the Rot13 application
located in `$TPC_HOME/kernel/rot13`. C/C++ builds in TPC use `cmake`, a
cross-platform Makefile generator (see [1]). The pattern you see below repeats
for all CMake projects:

        [tpc@zed] cd $TPC_HOME/kernel/rot13 && mkdir -p build && cd build
        [tpc@zed] cmake -DCMAKE_BUILD_TYPE=Release .. && make

This will create a `build` subdirectory in which the `tpc_rot13` application is
begin build. You can also compile in debug mode by using `cmake ..` instead.

        -- The C compiler identification is GNU 5.3.0
        -- The CXX compiler identification is GNU 5.3.0
        -- Check for working C compiler: /usr/bin/cc
        -- Check for working C compiler: /usr/bin/cc -- works
        -- Detecting C compiler ABI info
        -- Detecting C compiler ABI info - done
        -- Detecting C compile features
        -- Detecting C compile features - done
        -- Check for working CXX compiler: /usr/bin/c++
        -- Check for working CXX compiler: /usr/bin/c++ -- works
        -- Detecting CXX compiler ABI info
        -- Detecting CXX compiler ABI info - done
        -- Detecting CXX compile features
        -- Detecting CXX compile features - done
        -- Configuring done
        -- Generating done
        -- Build files have been written to: /home/tpc/threadpoolcomposer/2016.03/kernel/rot13/build
        Scanning dependencies of target tpc-rot13
        [ 25%] Building CXX object CMakeFiles/tpc-rot13.dir/tpc_rot13.cpp.o
        [ 50%] Linking CXX executable tpc-rot13
        [ 50%] Built target tpc-rot13
        Scanning dependencies of target rot13
        [ 75%] Building CXX object CMakeFiles/rot13.dir/rot13.cpp.o
        [100%] Linking CXX executable rot13
        [100%] Built target rot13

Now there should be a `tpc-rot13` executable. As a first argument, pass a text
file to be ciphered; there is an ASCII version of the Shakespeare play
"All\'s well that ends well" in `~/allswell.txt`. Let us test the application
by enciphering it twice, this should give the original text back:

        [tpc@zed] ~/threadpoolcomposer/2016.03/kernel/rot13 $ ./tpc-rot13 ~/allswell.txt > test.txt
        [tpc@zed] ~/threadpoolcomposer/2016.03/kernel/rot13 $ ./tpc-rot13 test.txt

If everything goes well, the plain text should appear on the screen now.

**Congratulations!** This concludes the tutorial. We have seen how to build the
TPC libraries, load bitstream and driver and compile TPC API applications. Of
course this does not give a complete overview of TPC, but hopefully it provides
a solid starting point to start exploring. The Rot13 application is simple
enough to explore the basics; a next step could be the `basic_test` example in
`$TPC_HOME/examples/basic_test`. There is a TPC configuration for three basic
testing kernels, which perform read, write and r+w accesses on main memory
respectively. Check out the kernels `arraysum`, `arrayinit` and `arrayupdate` in
`$TPC_HOME/kernel` and try to run the example.

Debugging
---------
This document is over; everything runs perfectly fine, so why are you still
reading? ;-) Just joking! As the saying goes "Hardware is hard", and it still
takes a lot of time to get even a moderately complex application running on the
FPGA. On the way there will be problems, and since there are so many moving
parts in between the software application and the hardware in the fabric, we
need all the debugging help we can get. this section is concerned with some of
the debugging facilities of TPC.

First of all, switch to the release mode libraries only towards the end, when
your application is running and stable. Until then, use the debug libraries.
To compile the libraries in debug mode, use:

        [tpc@zed] ~ tpc-build-libs --mode debug

This will enable logging in the libraries. Logging is controlled by four
environment variables:

1. `LIBPLATFORM_DEBUG`
2. `LIBPLATFORM_LOGFILE`
3. `LIBTPC_DEBUG`
4. `LIBTPC_LOGFILE`

The `_DEBUG` variables are a bit mask for various parts of the libraries; you
can turn on debug information selectively for each part. See
`$TPC_HOME/arch/common/include/tpc_logging.h` and
`$TPC_HOME/platform/common/include/platform_logging.h` for further information.

You can simply turn on all logs by using

        [tpc@zed] ~ export LIBPLATFORM_DEBUG=-1
        [tpc@zed] ~ export LIBTPC_DEBUG=-1

The `_LOGFILE` variables can be used to redirect the log output to logfiles
(instead of stdout), e.g.:

        [tpc@zed] ~ export LIBTPC_LOGFILE=/home/tpc/libtpc.log
        [tpc@zed] ~ export LIBPLATFORM_LOGFILE=/home/tpc/libplatform.log

Usually this level of debug information is sufficient. But in case something is
going wrong on the driver level, you can also compile the device driver in debug
mode like this:

        [tpc@zed] ~ cd $TPC_HOME && ./buildLibs.py driver_debug

This will activate another bitmask in the driver; you can access it via the
sysfs file `/sys/module/tpc_platform_zynq/parameters/logging_level`. To activate
all debug messages use:

        [tpc@zed] ~ sudo sh -c 'echo -1 > /sys/module/tpc_platform_zynq/parameters/logging_level'

You can see the log messages in the system log, accessible via `dmesg`:

        [tpc@zed] ~ dmesg --follow

Run this command in a separate shell and you can see the log message during the
execution of your application.

**Note:** Logging at the driver level costs _a lot of performance_! It is
entirely possible that your application has different concurrent behavior with
it activated, even with `logging_level` at `0`. Always make sure to switch back
to release mode in the driver before measurements. Logging in user spaces (i.e.,
in the libraries) is not as expensive and we have tried to implement logging
with minimal runtime overhead. But the Zynq CPUs are severely limited in terms
of performance, so a performance hit will be measurable for library logging, too.
So, for benchmarking always use the release mode of driver and libraries.

We hope ThreadPoolComposer is useful to you and can help to get your FPGA
research started as quickly as possible! If you use TPC in your research we
kindly ask that you cite our FCCM 2015 paper (see [2]) in your papers.
Even more importantly, let us know about issues with TPC and share your
improvements and patches with us - TPC is meant as a tool for the FPGA community
and would hugely benefit from our joint expertise. If you encounter any problems,
please check the Wiki at [3], file a bug in the bugtracker or contact us
directly via email.

Have fun!

[1]: https://cmake.org/documentation/
[2]: http://www.esa.informatik.tu-darmstadt.de/twiki/bin/view/Downloads/ThreadPoolComposer.html
[3]: https://git.esa.informatik.tu-darmstadt.de/REPARA/threadpoolcomposer
