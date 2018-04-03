TaPaSCo Loadable Kernel Module (TLKM)
=====================================

This is the second generation of TaPaSCo FPGA device drivers, which unifies all
supported Platforms in a single kernel module. Previously, each class of device
(e.g., Zynq and PCIe) required a separate module, repeating several tedious
kernel-level implementations. It defines a primitive "bus", which detects
TaPaSCo devices, and for the first time enables more than one device at a time.
This necessitated a more-or-less complete rewrite of the kernel module, but
should make it simpler to support new devices as they're being released.

Table of Contents
-----------------

  1.  <a href="#changes">Changes</a>
  2.  <a href="#dirs">Directory Structure</a>
  3.  <a href="#overview">Overview</a>
  4.  <a href="#user-space-ifs">User-Space Interfaces</a>
  5.  <a href="#devices">TaPaSCo Devices</a>
  6.  <a href="#device-ifs">Device User-Space Interfaces</a>
  7.  <a href="#perfc">Performance Counters</a>

Changes <a name="changes"/>
-------

  *  single LKM for all devices
  *  defines TaPaSCo bus to enumerate TaPaSCo compatible devices
  *  facilitates re-use of shared/repeated components, e.g., performance counters
  *  number of file interfaces has been reduced
  *  strongly structured code, every subsystem follows a strict pattern using
     _init and _exit functions, making it easier to parse
  *  blocking interfaces in kernel have been dropped; if requested by user space,
     they will be emulated via the asynchronous interface

Directory Structure <a name="dirs"/>
-------------------

```
/			<- should only contain the top-level module definitions
/tlkm			<- contains code for top-level device management
/common			<- contains re-usable shared code and definitions
/user			<- contains headers to be included in user-space progs
/<PLATFORM>		<- contains platform specific code and enumerators
```

Overview <a name="overview"/>
--------

The base module only initializes `tlkm_bus`. `tlkm_bus` calls a number of device
enumerators from the `/<PLATFORM>` subdirectory to get a list with names and 
device ids (see `common/tlkm_devices.h` for the `struct` def). The init and exit
function pointers link to the platform-specific code for device initialization
and tear-down. They will be used when user space creates the corresponding
device to setup the device-specific OS interfaces.

User-Space Interfaces <a name="user-space-ifs"/>
---------------------

TLKM tries to limit the number of user-space interfaces as much as possible.
Previous attempts with using many different `sysfs` files and similar approaches
have exhibited a significant overhead due to the increased number of syscalls.
The best performing solution (by far) was achieved by using `ioctls` and
implementing rather high-level commands, which do as much as possible within one
syscall.

Following this thought to its logical extreme, TLKM exhibits a single dev file
called `tlkm`, which controls the bus and gates device access. Its `ioctl`
interface primarily allows to **enumerate, create and destroy devices**. It also
allows to check the TLKM version and provide other metadata.

Tapasco Devices <a name="devices"/>
---------------

TLKMs main `ioctl` interface is defined in `/tlkm/tlkm_ioctl.h` and allows to
create a device with one of three access types:

  *  **exclusive access**: Grants the caller the right to do whatever with the
     device, with no consideration of other users required. This requires that
     the device is either not instantiated yet, or has been instantiated in
     monitoring mode (see below).
  *  **shared access**: Grants the caller restricted access to the device, which
     is shared with other processes. This requires that the device has not been
     instantiated in exclusive mode.
     _Note: No current TLKM device type supports this kind of access yet._
  *  **monitoring access**: Grants the caller read-access to the device. This
     kind of access is always possible and meant for monitoring applications,
     such as `tapasco-debug`. It is the user's and the monitoring application's
     responsibility to access the device carefully and expect a different
     process to interact with it.

Device User Space Interfaces <a name="device-ifs"/>
----------------------------

Once created via the main `ioctl` interface, each tapasco device should create
a device file called `tlkm_<DEV_ID>` which supports the following user-space
interfaces on this file:

  *  `ioctl`: The device `ioctl` interface described in `/user/tlkm_device_ioctl.h`
  *  `read` : asynchronous completion interface, yields completed slot ids
  *  `write`: manually insert an acknowledge for the written slot id (optional)

It possible to extend the common `ioctl` interface with custom commands specific
to a platform by supporting additional `ioctls` in addition to those in
`/user/tlkm_device_ioctl.h`. Correct usage of such extended commands is up to
the user space program. A valid platform-specific implementation should always
return an error on commands it does not understand or implement.

Performance Counters <a name="perfc"/>
--------------------

Optionally, if TLKM is configured with performance counters, each device may
additionally have a `tlkm_<DEV_ID>_perfc` file giving access to device internal
performance counters, e.g., the total number of completed jobs, or the number of
completed jobs per slot.

**Important:** Performance counters are defined in `/common/tlkm_perfc.h` and
should always be the same for all devices. Defining a new performance counter
there automatically defines `tlkm_perfc_<name>_inc` and `tlkm_perfc_<name>_get`
functions, which can be used by your driver to access the counters. If you need
an additional counter, define it there - even if it specific to your platform!
The automatic implementation will take care that the counter is always zero on
platforms which don't use it and that the output format of the file is
consistent. This makes it easier to parse the reports with external tools.

