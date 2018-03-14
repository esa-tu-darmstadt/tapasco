Debugging with tapasco-debug
============================

Since a lot of the analysis facilities required to debug TaPaSCo designs are
very generic, there is a tool called `tapasco-debug` that shall provide their
implementations for general purposes. `tapasco-debug` is a simple ncurses-based
terminal application that provides a number of tools in subenvironments called
_Screens_. Each screen can be reached from the main menu and offers a different
toolset. The currently implemented screens are described below. Note that the
main menu is designed to hide menu options which are not available on the
current bitstream (as far as it is possible to detect), so not all of the
screens below may be available for your bitstream. Requirements for each screen
are listed below. Unless explicitly specified otherwise, pressing `q` will exit
the current screen, or the application when you're already in the main menu.

  1.  [Kernel Map Screen](#kernel-map)
  2.  [Interrupt Stress Test Screen](#intc-test)
  3.  [Register Monitor Screen](#monitor)

Kernel Map Screen <a name="kernel-map"/>
-----------------

### Requirements

None.

### General Function

Displays the kernel id and/or the memory at each virtual TaPaSCo slot in the
currently loaded bitstream. It also displays some metainformation from the
TaPaSCo status core in the design, e.g., versions of Vivado and TaPaSCo this
bitstream was built with and the frequencies of host, design and memory
interfaces.

### Interactions

None, every keypress exits the screen.


Interrupt Stress Test Screen <a name="intc-test"/>
----------------------------

### Requirements

At least one kernel with ID #14 - this must be a kernel which accepts a number
of clock cycles as its first argument and raises an interrupt after that delay.

### General Function

While building the base support for a new platform in TaPaSCo, a notoriously
error-prone element is correct interrupt handling. This screen aims to provoke
race conditions in the interrupt handling by starting concurrent executions on
counter kernels.

### Interactions

`+`: Starts a new thread which launches jobs on the counters with randomized
     duration and counts the number of jobs executed.

`-`: Terminates a thread.

### Notes

To get a useful test, there should be more than one counter PE and at least two
threads running (the more, the better - increases likelihood of race conditions).


Register Monitor Screen <a name="monitor"/>
-----------------------

### Requirements

None.

### General Function

Displays a live view of the PE registers in the currently loaded bitstream. This
can be useful to check on how arguments are passed and stored in the registers,
or to rule out cache-related problems. In this screen, you can also
**peek and poke** arbitrary addresses on the device.

### Interactions

`r`: _Read_ (peek) an address in the register address space. Opens a menu that
     enquires the address and a safety confirmation (you can crash your system
     by reading from an invalid bus address, so be careful).

`p`: _Poke_ a value to an address in the register address space. Opens a submenu
     where you can enter the address and the value, which will be written after
     confirmation.

`w`: _Poke and wait_ - specific function to start a PE manually and await its
     interrupt; can be useful to test execution and interrupt handling.
