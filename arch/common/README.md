# Common code snippets for Architecture implementations
Every implementation of a new Architecture for *Tapasco* must provide
an implementation of TPC API, and many tasks will have to be re-implemented with
no significant changes. The code snippets in `src` are meant to be re-usable
in new implementation and provide a quick way implement the job management and
other such tasks. They are very primitive, but should facilitate iterative
replacement with better code; they are written in standard C, using only some
gcc notation for atomics, which should make them amenable for inclusion in 
Linux device driver code as well.

# Code snippet headers
The headers in `include` define primitive micro APIs, which should allow to 
replace each of the snippets with a custom implementation. Their usage and
meaning is documented inline in the code, but HTML documentation can be
generated using [doxygen](http://www.doxygen.org).

# Unit test for code snippets
Though their implementation is rather straight-forward and simple-as-possible,
bugs in this code can produce really subtle bugs in the overall project. The
directory `test` therefore contains a number of unit tests written with the
[check framework](http://check.sourceforge.net). Use the make file in the
directory to perform regression testing on the implementation.

