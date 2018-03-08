Debugging with TaPaSCo
======================

TaPaSCo designs don't have bugs, so no debugging facilities are required.
Right? Right. Well.

...

You're still reading? Goodness, why? ;-) Ok. so let's assume hypothetically that
your design would have a bug as a Gedankenexperiment. This document is about the
available facilities in TaPaSCo to hunt it down.

Table of Contents
-----------------

  1.  [Hunting hardware bugs](#hw-bugs)
      a.  [The debug feature](#debug-feature)
      b.  [Exercise an ILA](#use-ila)
  2.  [Hunting software bugs](#sw-bugs)
      a.  [tapasco-debug](#tapasco-debug)
      b.  [tapasco-benchmark](#tapasco-benchmark)

Hunting hardware bugs <a name="hw-bugs"/>
---------------------

To test the hardware interface of PE modules, use the peek and poke utilities in
[tapasco-debug](#tapasco-debug). It allows you to manually interact with the
registers of the module, peeking at the ISR and other registers, and even start
jobs.

If the bug does not concern the PE module interface, but something else in the
design, it is best to instantiate a (System) Integrated Logic Analyzer (ILA)
core in the design: ILA can record small traces in on-chip buffers, which can be
read out via Vivado to see actual signals in the running hardware. Recording can
be triggered by simple and complex conditions, making it feasible to debug on
real hardware. Since this is something that one needs to time and time again,
there's a TaPaSCo _feature_ that can automatically instantiate ILA cores in
compositions, which is shown in the next section.

The debug composition feature <a name="debug-feature"/>
-----------------------------

The `debug` feature can be added to any composition and can be configured in two
modes: `interfaces` mode and `nets` mode. The `interfaces` mode instantiates a
System ILA core during the generation of the Architecture. Its primary use is to
"listen" to transactions on AXI4 interfaces. To connect to an AXI4 interface,
you need to specify the (fully qualified) bus interface port and the
corresponding clock and reset pins. Example:

```
tapasco compose [precision_counter x 1] @ 100 Mhz --features 'Debug { interfaces: "{{/arch/target_ip_00_000/S00_AXI /arch/target_ip_00_000/s00_axi_aclk /arch/target_ip_00_000/s00_axi_aresetn }}" }'
```

This will attach a System ILA to the `S00_AXI` interface nets of the first
`precision_counter` instance.

The `nets` mode allows to connect to arbitrary nets (including nets within IP
cores which would not be visible in IP integrator). For this reason, it requires
two synthesis runs: First, the whole design without the ILA must be synthesized
into a netlist; then the ILA core is instantiated using a constraints file. This
requires a re-run of synthesis to take effect. Nets can be specified with
wildcards, patterns can be tested on a synthesized design using the Tcl console
in Vivado (use `get_bd_nets <pattern>` to test the pattern).

Example:

```
tapasco compose [precision_counter x 1] @ 100 Mhz --features 'Debug { nets: "{system_i/arch/target_ip_00_000/* system_i/arch/irq*}" }'
```

This would attach an ILA core to all nets attached to the first instance of the
first PE and all interrupt outputs of the entire Architecture. 

Exercise an ILA <a name="use-ila"/>
---------------

You can connect to the generated ILAs by starting Vivado by opening the
`microarch.xpr` in the subdirectory of the composition (probably below `bd`).
Open "Hardware Manager", connect to the board and the ILAs should already be
visible. Consult the Xilinx user guides for more information on ILA debugging.

Blinkenlights debugging
-----------------------

Sometimes an ILA is overkill, e.g., when you really just want to see whether or
not an interrupt line is high, or similar signals of few bits. In this case it
can be helpful to use on-board LEDs to communicate the wire states. This can be
achieved with the `LED` feature, which is available on most Platforms:

```
tapasco compose [precision_counter x 1] @ 100 Mhz --features 'LED { inputs: "{system_i/arch/target_ip_00_000/interrupt system_i/arch/irq_0}" }'
```

On most platforms, default inputs are defined to be the interrupt lines of the
Architecture and the Platform components; if this matches your case, you can
simply use `LED { enabled: true }` instead.

The `zedboard` Platform has an on-board 128x34px OLED display, which can be used
to display interrupt counts on every PE: Every pixel represents one interrupt
event on the interrupt line of the corresponding PE. Example for a composition
with 128 PEs:

```
x...............................x...............................................................................................
xxx.............................xx..............................................................................................
xx..............................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................................................
................................................................................................xxx.............................
```

In this example, there have been 1 interrupt on PE#0, 3 interrupts on PE#1, 2
interrupts on PE#2, 1 interrupt on PE#32, 2 interrupts on PE#33 and 3 interrupts
on PE#127. The counters wrap-around on overflow. The display controller scales
the column width automatically according to the number of PEs in the composition.
E.g., a composition with 64 PEs would use 64 pixels for the counter, a
composition with less than 33 PEs would use 128 pixels.

Hunting software bugs <a name="sw-bugs"/>
---------------------

Software is slightly easier to debug. First step should be to build all modules
and libraries, as well as the application, in _debug mode_. This can be achieved
by either

```
tapasco-build-libs --rebuild --mode debug
```

This will rebuild the TaPaSCo libraries with logging facilities enabled. Logging
is controlled via **environment variables** listed in the table below.

|:**Env Var**           |:**Description**                                      |
|-----------------------|------------------------------------------------------|
| `LIBTAPASCO_DEBUG`    | Bitfield that enables/disables logging of subsystems |
|                       | in `libtapasco`, see below for details, -1 for all.  |
| `LIBPLATFORM_DEBUG`   | Bitfield that enables/disables logging of subsystems |
|                       | in `libplatform`, see below for details, -1 for all. |
| `LIBTAPASCO_LOGFILE`  | Redirects logging output from `libtapasco` to the    |
|                       | file specified here; can use absolute paths.         |
| `LIBPLATFORM_LOGFILE` | Redirects logging output from `libplatform` to the   |
|                       | file specified here; can use absolute paths.         |

The `LIBTAPASCO_DEBUG` bitfield enables logging in specific subsystems. Current
implementation is defined in the `LIBTAPASCO_LOGLEVELS` macro in
[tapasco_logging.h](arch/common/include/tapasco_logging.h). For reference, the
following bits are defined as of the time of writing:

|:**Bit #**|:**Description**                                                   |
|---------:|-------------------------------------------------------------------|
| 0        | _Reserved_	                                                       |
| 1        | Initialization - startup messages                                 |
| 2        | Device - interactions with the kernel module                      |
| 3        | Scheduler - TaPaSCo software scheduler                            |
| 4        | Interrupts                                                        |
| 5        | Memory                                                            |
| 6        | Function - hardware registers and enumeration                     |
| 7        | Status - TaPaSCo status core                                      |

The `LIBPLATFORM_DEBUG` bitfield enables logging from specific `libplatform`
subsystems. Current implementation is defined in the `LIBPLATFORM_LOGLEVELS`
macro in
[platform_logging.h](platform/common/include/platform_logging.h). For reference,
the following bits are defined as of the time of writing:

|:**Bit #**|:**Description**                                                   |
|---------:|-------------------------------------------------------------------|
| 0        | _Reserved_	                                                       |
| 1        | Initialization - startup messages                                 |
| 2        | Memory management                                                 |
| 3        | Memory allocator                                                  |
| 4        | Control Space interactions                                        |
| 5        | Interrupts                                                        |
| 6        | DMA related                                                       |

As a safe bet, simply use `-1` to activate all logging subsystems. Note that the
logging system is designed to be as unintrusive as possible; string operations
are always costly and _will_ affect your runtime, but TaPaSCo attempts to
minimize the impact by moving logging to a separate thread and keeping buffers
that will only flush occasionally. So you shouldn't expect the log output to
appear immediately - by default, TaPaSCo installs a signal handler that will
catch a `KILL` signal and flush logs, so you can use that to if your application
is stuck.

The tapasco-debug tool
----------------------

There's a versatile debugging tool that comes with TaPaSCo and is automatically
build by `tapasco-build-libs` called `tapasco-debug`. It can be used to inspect
bitstreams, peek and poke registers and perform basic functionality tests. One
of its most common features is the _kernel map_, which displays the function ids
of PEs in all virtual slots in the currently loaded bitstream, as well as host,
design and memory clock frequencies.

The tapasco-benchmark tool
--------------------------

Another tool that can sometimes be useful is `tapasco-benchmark` (also
automatically build by `tapasco-build-libs`). It performs a basic performance
evaluation of the Platform and stores the results in a JSON file. This file can
in turn be used by the design space exploration. Each Platform comes with a
pre-computed results file, e.g., [pynq](platform/pynq.benchmark). However, to
calibrate the DSE it may be useful to update the benchmarks on your own system.

**WARNING**: Make sure you've built everything in _release_ mode before updating
the benchmark data!

`tapasco-benchmark` requires a bitstream with at least one PE for a kernel with
id 14 - the counter. Counters are simple: Arg#0 is the number of clock cycles to
wait before raising the interrupt - that's it. One example of such a kernel is
[precision_counter](common/ip/precision_counter_1.0). You can build and import
it like this:

```
cd $TAPASCO_HOME/common/ip && \
zip -r precision_counter.zip precision_counter_v1.0 && \
tapasco import $(TAPASCO_HOME)/common/ip/precision_counter.zip as 14
```

Alternative implementations are also available, e.g., [counter](kernel/counter),
which is an Vivado HLS implementation of the same functionality. It can be built
using:

```
tapasco hls counter
```

