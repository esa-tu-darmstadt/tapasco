TaPaSCo and Json-Files
======================

TaPaSCo uses Json-Files to store information about many specific entities. The following base-entities rely on json files:

* kernels
* platforms
* architectures
* cores 

As a User, kernels are generally the only json-Files relevant. They are necessary to allow the use of the TaPaSCo HLS feature with custom C/C++ code. To ensure correct use of these Files, TaPaSCo uses a rigorous json-parser, which validates the json-Files and prints out errors accordingly. Mostly these error Messages can already help with correcting the json-files. The following sections will further describe the attributes of certain json-Files.


Table of Contents
-----------------

    1. [kernel.json](#kernels)
    
    
kernel.json <a name="kernels"/>
-----------
The kernel.json File contains all relevant information about a HLS-Target. It tells TaPaSCo which function to synthesize and how to attach it to the surrounding architecture. Thus, a valid kernel.json File has to contain certain attributes:

* Name : The name of the Kernel, acts as Identification and can be any non-empty String.
* TopFunction : The function to use ase Top-Level Function for HLS and corresponds to the function name in your code (Only the function Name, no return Types are parameters!)
* Id : Is a number which is used by TaPaSCo to identify the resulting Core in HW. This Id is a Int number which is >= 1.
* Version : Is a String that gives information about the version of your kernel.
* Files : An Array of relative filenames as Strings indicating which Code-Files are required by your kernel. This includes the file containing the TopFunction. The json-Parser will also resolve all File-Paths and check wether the files actually exist.
* Arguments : List of Arguments the TopFunction takes. Each Argument is represented by a json-object containing the field Name. Optionally, it can also specify whether the paramater is passed by value or by reference.
* TestbenchFiles : (Optional) Additional Files for use with Cosimultion
* Description : (Optional) Description of your kernel
* CompilerFlags : (Optional) Compiler Flags for use with HLS
* TestbenchCompilerFlags : (Optional) Compiler Flags for use with Cosimulation
* OtherDirectives : (Optional) additional File containing Directives for the Synthesis.

If a F
