# Runtime Plugin System

Custom extensions to the TaPaSCo hardware design may require initialization during runtime, e.g.,
setting of control registers. Usually, TaPaSCo hides any interaction with infrastructure IPs from
the user. However, we provide a plugin system for the TaPaSCo runtime.

All runtime plugins must be written in Rust and implement the `Plugin` trait defined in [plugin.rs](../runtime/libtapasco/src/plugins/plugin.rs).
The `init()` function is automatically called during construction of the `Device` object and may take care
of the initialization of your hardware extension. The `is_available()` function should return whether
the extension is included in the currently loaded bitstream, and the `as_any()` and `as_any_mut()` functions
should return a (mutable) reference to the plugin object.

Furthermore, your plugin can define and implement custom functions to provide any desired functionality.

Finally, you must register your plugin using the `declare_plugin()` macro for automatic loading during startup,
and add it to the plugin [mod.rs](../runtime/libtapasco/src/plugins/mod.rs).

In Rust applications, you can then retrieve a reference to the plugin object by calling `device.get_plugin::<YourPlugin>()`.

In order to make your plugin usable in C++ applications, you have to conduct two steps. First, you have to
implement an FFI interface exposing all functionality in external C functions, as this is also done for the
TaPaSCo runtime in [ffi.rs](../runtime/libtapasco/src/ffi.rs). Second, you have to write a C++ wrapper class holding
a pointer to the underlying Rust object and providing the plugin functionality with methods. This wrapper class must provide a static function `get_instance(Device *d)`
so that the plugin can be retrieved using the templated `Tapasco::get_plugin<T>()` method.

The NVMe runtime plugin implemented in [nvme.rs](../runtime/libtapasco/src/plugins/nvme.rs) and [tapasco-nvme.hpp](../runtime/libtapasco/src/plugins/tapasco-nvme.hpp)
 may be used as a reference.