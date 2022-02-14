TaPaSCo and Json-Files
======================

TaPaSCo uses json-files to store information about many specific entities. The following base-entities rely on this:

* kernels
* platforms
* architectures
* cores 

For a user, only `kernel.json` files are really relevant. They are necessary to allow the use of the TaPaSCo HLS feature with custom C/C++ code. To ensure correct use of these files, TaPaSCo uses a rigorous json-parser, which validates the json-files and prints out errors accordingly. Mostly these error messages can already help with correcting the json-files. The following sections will further describe the attributes of certain json-files.


Table of Contents
-----------------

  1. [kernel.json](#kernels)
  2. [platform.json](#platforms)
    
    
kernel.json <a name="kernels"/>
-----------
The `kernel.json` file contains all relevant information about an HLS-target. It tells TaPaSCo which function to synthesize and how to attach it to the surrounding architecture. Thus, a valid `kernel.json` file has to contain certain attributes:

* Name : The name of the kernel, acts as identification and can be any non-empty string.
* TopFunction : The function to use as top-level function for HLS and corresponds to the function name in your code. Note, that only the name is required, not the function signature.
* Id : Is a number which is used by TaPaSCo to identify the resulting core in HW. This id is an int number which is >= 1.
* Version : Is a string that gives information about the version of your kernel.
* Files : An array of relative filenames as strings indicating which files are required by your kernel. This includes the file containing the TopFunction. The json-parser will also resolve all filepaths and check whether the files actually exist.
* Arguments : List of arguments the TopFunction takes. Each argument is represented by a json-object containing the field Name. Optionally, it can also specify whether the parameter is passed by value or by reference.
* TestbenchFiles : (Optional) Additional files for use with Cosimultion
* Description : (Optional) Description of your kernel
* CompilerFlags : (Optional) Compiler flags for use with HLS
* TestbenchCompilerFlags : (Optional) Compiler flags for use with Cosimulation
* OtherDirectives : (Optional) additional file containing directives for the synthesis.

If a file does not provide all the non-optional fields, this will result in errors and is thus not accepted by TaPaSCo.

platform.json <a name="platforms"/>
-------------
The platform.json File contains all required platform-data. It has several uses inside TaPaSCo, from providing hard limits to frequencies as well as keeping references to required files containing TCL-templates, etc.
The following attributes are relevant:

* Name : The name of the platform (eg. "pynq")
* TclLibrary : The path to a TCL-file required for generating the surrounding architecture. (eg. "pynq.tcl")
* Part : The partname of the chip used on the platform
* MaximumDesignFrequency: Double value indicating the maximum achievable frequency on this Platform.
* BoardPart : (Optional) The identification of the Board.
* Benchmark : (Optional) Path to a benchmark file
* Description : (Optional) Description of the platform, eg. "Pynq-Z1 Python Productivity for Zynq"
* TargetUtilization : (Optional) Percentage (as int between 0 and 100) that indicates how much of the FPGA is realistically usable.
