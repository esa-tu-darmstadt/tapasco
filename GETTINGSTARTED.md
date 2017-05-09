ThreadPoolComposer -- Getting Started
=====================================
This document will walk you through an example bitstream creation with TPC.
But first we will discuss some basic terminology and explain how TPC works
in general.

Terminology
-----------
*   _Platform_
    Hardware platform, i.e., the basic, unchangeable environment with which
    your design has to connect. Different boards will usually have different
    _Platforms_ to take advantage of all available hardware components. E.g.,
    there is a `zedboard` Platform for the zedboard, which has an OLED display
    which other Zynq device do not have. More importantly, the _Platform_
    abstracts the basic hardware substrate, i.e., access to memory and host
    communication.

*   _Architecture_
    The basic template for your hardware thread pool, i.e., the organisation
    of your _Core instances. Currently there is only one such _Architecture_
    called `baseline`.

*   _ThreadPool_
    Consists of a number of _Processing Elements (PEs)_, which can all operate
    simulateneously.

*   _Processing Element (PE)_
    A hardware IP core that performs a specific computational function. These
    are the building blocks of your design in TPC. Each PE is an _instance_ of
    a _Core_.

*   _Core_
    A custom IP core described by an IPXACT \[[2]\] description. This is the
    file format the Vivado IP Integrator uses in its IP Catalog. It usually 
    consists of a single .zip file with a `component.xml` somewhere inside it,
    which provides detailed description of all files, ports and modules of
    the IP core. For TPC, a _Core_ also contains a basic evaluation report,
    i.e., an estimation of the area and the worst case data path delay / 
    maximal frequency the core can run at, which is device-dependent; therefore
    the same _Kernel_ may have many _Cores_, one for each _Platform_ +
    _Architecture_ combination.

*   _Kernel_
    Abstract description of a _Core_. More precisely, in TPC a _Kernel_ is the
    description of a custom IP core that can be built via _High-Level Synthesis_
    (HLS). The HLS step will generate a _Core_ suitable for the selected 
    _Platform_ and _Architecture_.

Basic Operation
---------------
TPC is basically a set of scripts which provide a (slightly) more convenient
interface to Vivado Design Suite to generate hardware designs which can be
used with uniform _Application Programming Interface (API)_ called __TPC API__.

The hardware generation flow consists of a series scripts which control the 
execution of the Vivado tools. TPC itself is written in Scala \[[3]\] and
primarily arranges files and data for the Vivado execution automatically.

It can automatically run Vivado HLS to generate IP cores and can perform a
primitive form of __Design Space Exploration (DSE)__, ranging over three design
parameters:

1. Design Frequency
2. Number of PEs (~ area)
3. Alternative Cores (cores with the same ID are treated as alternatives)

You can choose to optimize either or all at the same time. A word of warning:
As mentioned, this process is pretty primitive and will usually require several
complete P\&R sessions, each of which usually takes several hours to complete
(depending on your _Platform_ and _Cores_). Also note that it is not guaranteed
to find the "optimal" solution.

By default, TPC can issue __parallel builds__: The user selects a set of
_Architectures_, _Platforms_ and _Compositions_ and each combination will be 
executed in parallel. __Beware of combinational explosions! It is best to select
a single _Platform_, _Architecture_ and _Composition_ until you are certain that
everything works as expected (and you have enough licenses + CPU power).__

All the entities which TPC works on/with are described by _Description Files_
in JSON format \[[1]\]. By convention, TPC will automatically scan certain 
directories for the description files (see below). There exist five kinds of 
description files:

1.  _Kernel Descriptions_ (`kernel.description`)
    These files contain a _Core_ recipe for HLS.

2.  _Platform Descriptions_ (`platform.description`)
    Contains basic information about a _Platform_ and links the Tcl library
    that can be used to instantiate the _Platform_ in hardware. This library
    builds a basic frame where the rest of the design is connected to.

3.  _Architecture Descriptions_ (`architecture.description`)
    Contains a basic information about a `Architecture` and links to the Tcl
    library that can be used to instantiate the _Architecture_ in hardware.

4.  _Composition Descriptions_ (any name)
    Contains a _ThreadPool_ description, i.e., a list of _Cores_ and the number
    of desired instances. Can be provided inline in the _Configuration_.

5.  _Configuration Descriptions_ (any name)
    Can be provided as command line arguments to `tpc`, or (more conveniently)
    in a separate file. Contains all parameters for the current _Configuration_;
    the _Configuration_ determines for which _Platforms_, _Architectures_ and
    _Compositions_ bitstreams shall be generated, and configures optional 
    _Features_ of _Platform_ and _Architecture_. It also controls the basic
    execution environment, e.g., can re-configure directories etc.

Many of these description files reference other files. It is always possible to
specify absolute paths, but it is more convenient to use _relative paths_. By 
convention, all relative paths are resolved relative to the location of the
description file. 
   
Directory Structure
-------------------
All paths in TPC can be reconfigured using _Configuration_ parameters, but when
nothing else is specified, the default directory structure below `$TPC_HOME` is
used:

*   `arch`
    Base directory for _Architectures_; will be searched for
    `architecture.description`s.

*  `bd`
   _Output directory_ for complete hardware designs generated by TPC (generated
   on first use). Organized as `<COMPOSITION NAME/HASH>/<ARCH>/<PLATFORM>`.

*  `core`
   _Output directory_ for _Cores_ (generated on first use); contains the TPC IP
   catalog. Organized as `<KERNEL>/<ARCH>/<PLATFORM>`.

*  `kernel`
   Base directories for _Kernels_; will be searched for `kernel.description`s.

*  `platform`
    Base directory for _Architectures_; will be searched for
    `architecture.description`s.

There are some more directories in `$TPC_HOME`, but only TPC developers need to
concern themselves with them. As a TPC user it is sufficient to understand the
directory structure above. Each base path can be reconfigured in the
_Configuration_, which is most useful for _Kernels_, e.g., to switch between
benchmark suites.

Tutorial
--------
Finally, we can start with the tutorial itself. In this example we will produce
a bitstream containing only a single _Kernel_, an implementation of the ROT13
cipher (also called Caesar cipher). ROT13 shifts all occurrences of the 26 
letters of the latin alphabet by an offset of 13 (with wrap-around). There are
documented uses of this "encryption" in the Roman Empire, where it was
(presumably) used to keep people from reading messages "over the shoulder".

We will use `itpc` to create a configuration file for us, so start it:

1.  `itpc`
    TPC should greet you with a menu similar to this:

        Welcome to interactive ThreadPoolComposer
        *****************************************
        
        What would you like to do?
        	a: Add an existing IPXACT core .zip file to the library
        	b: List known kernels
        	c: List existing cores in library
        	d: Build a bitstream configuration file
        	e: Exit
        Your choice: 

2.  Select `d` by entering `d<RETURN>`.

        Select Platform(s)[|x| >= 1]: 
        	a ( ): vc709
        	b ( ): zedboard
        	c ( ): zynq
        Your choice (press return to finish selection): 

3.  This is a menu that allows multiple choices; there is a constraint on your
    choice that is represented by `[|x| >= 1]`, which is supposed to mean that
    you have to select at least one _Platform_.
    Select the zedboard _Platform_ by `c<RETURN>`:

        	a ( ): vc709
        	b ( ): zedboard
        	c (x): zynq
        Your choice (press return to finish selection): 

4.  Exit the menu by `<RETURN>`:

        Design Space Exploration Mode[]: 
        	a: DesignSpaceExplorationModeNone
        	b: DesignSpaceExplorationModeFrequency
        	c: DesignSpaceExplorationModeAreaFrequency
        Your choice: 

5.  Let\`s keep it simple, choose None via `a<RETURN>`

        Select a kernel[]: Select a kernel
        	a: arrayinit
        	b: arraysum
        	c: arraysum-noburst
        	e: countdown
        ...
        	l: rot13
        Your choice: 

6.  Next step is to build the composition, `itpc` lists the available _Kernels_
    and _Cores_, choose `rot13` via the corresponding key.

        Number of instances[> 0]: 

7.  Choose any number > 0, e.g, `2<RETURN>`

        Add more kernels to composition?[]: 
        	a: true
        	b: false
        Your choice: 

8.  `itpc` will keep asking whether you want to add more kernels. Finish the
    composition by `b<RETURN>`.

        LED: Enabled[]: 
        	a: true
        	b: false
        Your choice: 

9.  Next, `itpc` will query all currently implemented feature of the _Platform_:
    `LED` means that there\`s a simple controller for the on-board LEDs to
    to show the internal state (available on Zynq, VC709).
    `OLED` is only available on zedboard, shows the number of interrupts that
    occurred at each PE visually.
    `Cache` activates a Xilinx System Cache as a sort-of L2 (doesn\`t work with
    the latest version, working on it).
    `Debug` adds VIO cores to the main input and output ports of the design;
    currently only implemented on `zedboard`, designs are not likely to build,
    but can occasionally be useful.
    Answer all these questions as you like.

        Enter filename for configuration[]: 

10. Finally, `itpc` asks for a file name for your configuration file. Choose
    anything you like, e.g., `test.cfg`.

        Run ThreadPoolComposer with this configuration now?[]: 
        	a: true
        	b: false
        Your choice: 

11. You can run Vivado directly now via `a<RETURN>`.

This process will take between 30min and 5h, depending on your choices and
generate a lot of output in between. It will mention the location of the Vivado
logfiles, you can watch them via `tail --follow <FILE>` on a separate shell,
if you like. 

If everything went well, there should be a `.bit` file in 
`$TPC_HOME/bd/<YOUR BD>/baseline/zedboard` afterwards (refer to the logging
output for the value of `<YOUR BD>` - if you had used an external _Composition_
description file, it would use that name instead of the hash).

In the same directory is a subdirectory called `bit` which contains the Vivado
project. You can open it and work with it just as you would with any regular
project.

__Congratulations!__ If you reached this point, you\`ve just built your first
bitstream via TPC. That\`s it for now, continue reading in
[GETTINGSTARTED-zynq.md](GETTINGSTARTED-zynq.md) for a complete walkthrough on
the Zynq boards (zedboard, ZC06).

[1]: http://json.org
[2]: http://www.accellera.org/activities/working-groups/ip-xact
[3]: http://www.scala-lang.org
