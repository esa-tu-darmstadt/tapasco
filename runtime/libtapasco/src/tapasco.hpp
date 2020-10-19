/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
  Interface changes since Tapasco 2020.4:

    * `RetVal` now takes a pointer parameter instead of a reference.
    * All other wrappers use move constructors instead of references, e.g. `T
  &&t` instead of `T &t`.
    * `make` functions can be chained, e.g. makeInOnly(makeLocal(v));
    * `tapasco_info_t` is no longer available. Instead dedicated functions, e.g.
  `tapasco::design_frequency` can be used to retrieve the desired information.
*/

#ifndef TAPASCO_HPP__
#define TAPASCO_HPP__

#ifndef __clang__
#if __GNUC__ && __GNUC__ < 5
#error "g++ 5.x.x or newer required (C++11 features)"
#endif
#endif

#include <future>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>

#include <tapasco_inner.hpp>

namespace tapasco {
using job_future = std::function<int(void)>;

// Types which might still be used by legacy applications
typedef DeviceAddress tapasco_handle_t;
typedef PEId tapasco_kernel_id_t;
typedef int tapasco_res_t;
typedef int tapasco_device_capability_t;
typedef int tapasco_device_alloc_flag_t;
typedef int tapasco_device_copy_flag_t;

constexpr tapasco_res_t TAPASCO_SUCCESS = 0;

constexpr int PLATFORM_CAP0_ATSPRI = (1 << 0);
constexpr int PLATFORM_CAP0_ATSCHECK = (1 << 1);
constexpr int PLATFORM_CAP0_PE_LOCAL_MEM = (1 << 2);
constexpr int PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP = (1 << 3);
constexpr int PLATFORM_CAP0_AWS_EC2_PLATFORM = (1 << 6);

constexpr int default_legacy_caps =
    PLATFORM_CAP0_PE_LOCAL_MEM | PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP;

/**
 * Type annotation for TAPASCO launch argument pointers: output only, i.e., only
 *copy from device to host after execution, don't copy from host to device
 *prior.
 **/
template <typename T> struct OutOnly final {
  OutOnly(T &&value) : value(value) {}
  T value;
};

template <typename T> OutOnly<T> makeOutOnly(T &&t) {
  return OutOnly<T>(std::move(t));
}

/**
 * Type annotation for TAPASCO launch argument pointers: input only, i.e.,
 *only copy from host to device before execution. This behaviour might be
 *realised using const vs non-const types but the behaviour of const was not
 *not as clear to a user as it should be which leads to unwanted transfers.
 **/
template <typename T> struct InOnly final {
  InOnly(T &&value) : value(value) {}
  T value;
};

template <typename T> InOnly<T> makeInOnly(T &&t) {
  return InOnly<T>(std::move(t));
}

/**
 * Type annotation for Tapasco launch argument pointers: If the first argument
 * supplied to launch is wrapped in this type, it is assumed to be the
 *function return value residing in the return register and its value will be
 *copied from the return value register to the pointee after execution
 *finishes.
 **/
template <typename T> struct RetVal final {
  RetVal(T *value) : value(value) {}
  T *value;
};

/**
 * Type annotation for Tapasco launch argument pointers: If possible, data
 * should be placed in PE-local memory (faster access).
 **/
template <typename T> struct Local final {
  Local(T &&value) : value(value) {}
  T value;
};

template <typename T> Local<T> makeLocal(T &&t) {
  return Local<T>(std::move(t));
}

/**
 * Type annotation for Tapasco launch argument pointers: If possible, data
 * should be placed in PE-local memory (faster access).
 **/
template <typename T> struct Offset final {
  Offset(T &&value, uint64_t offset) : value(value), offset(offset) {}
  T value;
  uint64_t offset;
};

template <typename T> Offset<T> addOffset(uint64_t offset, T &&t) {
  return Offset<T>(std::move(t), offset);
}

/**
 * Wrapped pointer type that can be used to transfer memory areas from and to
 *a device.
 **/
template <typename T> struct WrappedPointer final {
  WrappedPointer(T *value, size_t sz) : value(value), sz(sz) {}
  T *value;
  size_t sz;
};

template <typename T> WrappedPointer<T> makeWrappedPointer(T *t, size_t sz) {
  return WrappedPointer<T>(t, sz);
}

/** A TAPASCO runtime error. **/
class tapasco_error : public std::runtime_error {
public:
  explicit tapasco_error(const std::string &msg) : std::runtime_error(msg) {}
  explicit tapasco_error(const char *msg) : std::runtime_error(msg) {}
};

static void handle_error() {
  int l = tapasco_last_error_length();
  char *buf = (char *)malloc(sizeof(char) * l);
  tapasco_last_error_message(buf, l);
  std::string err_msg(buf);
  std::cerr << err_msg << std::endl;
  free(buf);
  throw tapasco_error(err_msg);
}

class JobArgumentList {
public:
  JobArgumentList(Device *d) : device(d) { new_list(); }

  virtual ~JobArgumentList() {
    if (this->list_inner != 0) {
      tapasco_job_param_destroy(this->list_inner);
      this->list_inner = 0;
    }
  }

  void new_list() {
    if (this->list_inner != 0) {
      throw tapasco::tapasco_error("List already allocated.");
    }
    this->list_inner = tapasco_job_param_new();
    reset_state();
  }

  void reset_state() {
    this->deviceaddress = (DeviceAddress)-1;
    this->from_device = true;
    this->to_device = true;
    this->free = true;
    this->local = false;
    this->offset_used = false;
    this->offset = 0;
  }

  JobList **list() { return &list_inner; }

  void single32(uint32_t param) {
    tapasco_job_param_single32(param, this->list_inner);
  }

  void single64(uint64_t param) {
    tapasco_job_param_single64(param, this->list_inner);
  }

  void devaddr(DeviceAddress param) {
    tapasco_job_param_deviceaddress(param, this->list_inner);
  }

  void memop(uint8_t *ptr, uintptr_t bytes) {
    if (this->deviceaddress != (DeviceAddress)-1) {
      tapasco_job_param_prealloc(this->device, ptr, this->deviceaddress, bytes,
                                 this->to_device, this->from_device, this->free,
                                 this->list_inner);
    } else if (this->local) {
      tapasco_job_param_local(ptr, bytes, this->to_device, this->from_device,
                              this->free, this->offset_used, this->offset,
                              this->list_inner);
    } else {
      tapasco_job_param_alloc(this->device, ptr, bytes, this->to_device,
                              this->from_device, this->free, this->offset_used,
                              this->offset, this->list_inner);
    }
    this->reset_state();
  }

  void unset_from_device() { from_device = false; }
  void unset_to_device() { to_device = false; }
  void unset_free() { free = false; }
  void set_local() { local = true; }
  void set_offset(uint64_t offset) {
    this->offset_used = true;
    this->offset = offset;
  }

private:
  Device *device{0};
  JobList *list_inner{0};

  bool from_device{false};
  bool to_device{false};
  bool free{false};
  bool local{false};
  bool offset_used{false};
  uint64_t offset{0};
  DeviceAddress deviceaddress{(DeviceAddress)-1};
};

class TapascoMemory {
public:
  TapascoMemory(TapascoOffchipMemory *m) : mem(m) {}

  virtual ~TapascoMemory() {
    if (this->mem != 0) {
      tapasco_memory_destroy(this->mem);
      this->mem = 0;
    }
  }

  DeviceAddress alloc(uint64_t len) {
    DeviceAddress a = tapasco_memory_allocate(mem, len);
    if (a == (uint64_t)(int64_t)-1) {
      handle_error();
    }
    return a;
  }

  DeviceAddress alloc_fixed(uint64_t len, uint64_t offset) {
    DeviceAddress a = tapasco_memory_allocate_fixed(mem, len, offset);
    if (a == (uint64_t)(int64_t)-1) {
      handle_error();
    }
    return a;
  }

  int free(DeviceAddress a) {
    if (tapasco_memory_free(mem, a) == -1) {
      handle_error();
      return -1;
    }
    return 0;
  }

  void free(DeviceAddress handle, size_t const len,
            tapasco_device_alloc_flag_t const flags) {
    this->free(handle);
  }

  int copy_to(uint8_t *d, DeviceAddress a, uint64_t len) {
    if (tapasco_memory_copy_to(mem, d, a, len) == -1) {
      handle_error();
      return -1;
    }
    return 0;
  }

  int copy_to(uint8_t *src, DeviceAddress dst, uint64_t len,
              tapasco_device_copy_flag_t const flags) {
    return this->copy_to(src, dst, len);
  }

  int copy_from(DeviceAddress a, uint8_t *d, uint64_t len) {
    if (tapasco_memory_copy_from(mem, a, d, len) == -1) {
      handle_error();
      return -1;
    }
    return 0;
  }

  int copy_from(DeviceAddress src, uint8_t *dst, uint64_t len,
                tapasco_device_copy_flag_t const flags) {
    return this->copy_from(src, dst, len);
  }

private:
  TapascoOffchipMemory *mem;
};

class TapascoDevice {
public:
  TapascoDevice(Device *d) : device(d) {}

  virtual ~TapascoDevice() {
    if (this->device != 0) {
      tapasco_tlkm_device_destroy(this->device);
      this->device = 0;
    }
  }

  void access(tlkm_access const access) {
    if (this->device == 0) {
      throw tapasco::tapasco_error("Device not initialized.");
    }
    if (tapasco_device_access(this->device, access) < 0) {
      handle_error();
    }
  }

  int num_pes(int k_id) {
    int cnt = tapasco_device_num_pes(this->device, k_id);
    if (cnt < 0) {
      tapasco::handle_error();
    }
    return cnt;
  }

  PEId get_pe_id(std::string name) {
    PEId peid = tapasco_device_get_pe_id(this->device, name.c_str());
    if (peid == (PEId)-1) {
      tapasco::handle_error();
    }
    return peid;
  }

  TapascoMemory default_memory() {
    TapascoOffchipMemory *mem = tapasco_get_default_memory(this->device);
    if (mem == 0) {
      handle_error();
    }

    return TapascoMemory(mem);
  }

  Job *acquire_pe(PEId pe_id) {
    Job *j = tapasco_device_acquire_pe(this->device, pe_id);
    if (j == 0) {
      handle_error();
    }
    return j;
  }

  float design_frequency() {
    return tapasco_device_design_frequency(this->device);
  }

  Device *get_device() { return this->device; }

private:
  Device *device{0};
};

class TapascoDriver {
public:
  TapascoDriver() {
    tapasco_init_logging();
    this->tlkm = tapasco_tlkm_new();
    if (this->tlkm == 0) {
      handle_error();
    }
  }

  virtual ~TapascoDriver() {
    if (this->tlkm != 0) {
      tapasco_tlkm_destroy(this->tlkm);
      this->tlkm = 0;
    }
  }

  TapascoDevice allocate_device(DeviceId dev_id) {
    int num_devices = this->num_devices();
    if (num_devices == 0) {
      throw tapasco_error("No TaPaSCo devices found.");
    }

    if (dev_id > (DeviceId)num_devices) {
      std::ostringstream stringStream;
      stringStream << "ID " << dev_id << " out of device range (< "
                   << num_devices << ")";
      throw tapasco_error(stringStream.str());
    }

    Device *device = 0;

    if ((device = tapasco_tlkm_device_alloc(this->tlkm, dev_id)) == 0) {
      handle_error();
    }

    return TapascoDevice(device);
  }

  int num_devices() {
    // Retrieve the number of devices from the runtime
    int num_devices = 0;
    if ((num_devices = tapasco_tlkm_device_len(this->tlkm)) < 0) {
      handle_error();
    }
    return num_devices;
  }

private:
  TLKM *tlkm{0};
};

/**
 * C++ Wrapper class for TaPaSCo API. Currently wraps a single device.
 **/
struct Tapasco {
  /**
   * Constructor. Initializes device by default.
   * Note: Need to check is_ready if using auto-initialization before use.
   * @param initialize initializes TAPASCO during constructor (may throw
   *exception!)
   * @param dev_id device id of this instance (default: 0)
   **/
  Tapasco(tlkm_access const access = tlkm_access::TlkmAccessExclusive,
          DeviceId const dev_id = 0)
      : driver_internal(),
        device_internal(driver_internal.allocate_device(dev_id)),
        default_memory_internal(device_internal.default_memory()) {
    this->device_internal.access(access);
  }

  /**
   * Destructor. Closes and releases device.
   **/
  virtual ~Tapasco() {}

  TapascoDevice &device() { return device_internal; }
  TapascoDriver &driver() { return driver_internal; }
  TapascoMemory default_memory() {
    return this->device_internal.default_memory();
  }

  template <typename R, typename... Targs>
  job_future launch(PEId pe_id, RetVal<R> &ret, Targs... args) {
    JobArgumentList a(this->device_internal.get_device());
    set_args(a, args...);

    Job *j = this->device_internal.acquire_pe(pe_id);
    if (j == 0) {
      handle_error();
    }

    if (tapasco_job_start(j, a.list()) < 0) {
      handle_error();
    }

    return [this, j, &ret, &args...]() {
      uint64_t ret_val;
      if (tapasco_job_release(j, &ret_val, true) < 0) {
        handle_error();
      }
      *ret.value = (R)ret_val;
      return 0;
    };
  }

  template <typename... Targs> job_future launch(PEId pe_id, Targs... args) {
    JobArgumentList a(this->device_internal.get_device());
    set_args(a, args...);

    Job *j = this->device_internal.acquire_pe(pe_id);
    if (j == 0) {
      handle_error();
    }

    if (tapasco_job_start(j, a.list()) < 0) {
      handle_error();
    }

    return [this, j, &args...]() {
      if (tapasco_job_release(j, 0, true) < 0) {
        handle_error();
      }
      return 0;
    };
  }

  /**
   * Allocates a chunk of len bytes on the device.
   * @param len size in bytes
   * @param h output parameter for handle
   * @return TAPASCO_SUCCESS if successful, an error code otherwise.
   **/
  int alloc(DeviceAddress &h, size_t const len) {
    h = this->default_memory_internal.alloc(len);
    if (h == (DeviceAddress)(int64_t)-1) {
      return -1;
    }
    return 0;
  }

  int alloc(tapasco_handle_t &h, size_t const len,
            tapasco_device_alloc_flag_t const flags) {
    return this->alloc(h, len);
  }

  /**
   * Allocates a chunk of len bytes on the device and forces a given offset.
   * @param len size in bytes
   * @param offset in bytes
   * @param h output parameter for handle
   * @return TAPASCO_SUCCESS if successful, an error code otherwise.
   **/
  int alloc(DeviceAddress &h, size_t const len, size_t const offset) {
    h = this->default_memory_internal.alloc_fixed(len, offset);
    if (h == (DeviceAddress)(int64_t)-1) {
      return -1;
    }
    return 0;
  }

  /**
   * Frees a previously allocated chunk of device memory.
   * @param handle memory chunk handle returned by @see alloc
   **/
  void free(DeviceAddress handle) {
    this->default_memory_internal.free(handle);
  }

  /**
   * Copys memory from main memory to the FPGA device.
   * @param src source address
   * @param dst destination device handle
   * @param len number of bytes to copy
   * @param flags flags for copy operation
   * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
   **/
  int copy_to(uint8_t *src, DeviceAddress dst, size_t len) {
    return this->default_memory_internal.copy_to(src, dst, len);
  }

  /**
   * Copys memory from FPGA device memory to main memory.
   * @param src source device handle (prev. alloc'ed with tapasco_alloc)
   * @param dst destination address
   * @param len number of bytes to copy
   * @param flags flags for copy operation, e.g.,
   *TAPASCO_DEVICE_COPY_NONBLOCKING
   * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
   **/
  int copy_from(DeviceAddress src, uint8_t *dst, size_t len) {
    return this->default_memory_internal.copy_from(src, dst, len);
  }

  /**
   * Returns the number of PEs of kernel k_id in the currently loaded
   *bitstream.
   * @param k_id kernel id
   * @return number of instances > 0 if kernel is instantiated in the
   *         bitstream, 0 if kernel is unavailable
   **/
  int kernel_pe_count(PEId k_id) {
    int64_t cnt = this->device_internal.num_pes(k_id);
    return cnt;
  }

  /**
   * Returns the ID of the kernel with the given name.
   *
   * @param name Name of the kernel
   * @return number of the PE if available or an exception if PE type is not
   * available.
   **/
  int get_pe_id(std::string name) {
    return this->device_internal.get_pe_id(name);
  }

  float design_frequency() { return this->device_internal.design_frequency(); }

  std::string version() {
    uintptr_t len = tapasco_version_len();
    char *ptr = new char(len);
    tapasco_version(ptr, len);
    std::string s(ptr, len);
    delete (ptr);
    return s;
  }

  /**
   * Checks if the current bitstream supports a given capability.
   * @param cap capability to check
   * @return TAPASCO_SUCCESS, if capability is available, an error code
   *otherwise
   **/
  tapasco_res_t has_capability(tapasco_device_capability_t cap) {
    return default_legacy_caps & cap;
  }

private:
  /* Collector methods: bottom half of job launch. @} */

  /* @{ Setters for register values */
  /** Sets a single value argument. **/
  template <typename T> void set_arg(JobArgumentList &a, T t) {
    // only 32/64bit values can be passed directly (i.e., via register)
    if (sizeof(T) == 4) {
      a.single32((uint32_t)t);
    } else if (sizeof(T) == 8) {
      a.single64((uint64_t)t);
    } else {
      throw tapasco_error("Please supply large arguments as wrapped pointers.");
    }
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template <typename T> void set_arg(JobArgumentList &a, T *t) {
    throw tapasco_error("Pointers are not directly supported as they lack size "
                        "information. Please use WrappedPointers.");
  }

  /** Sets local memory flag for transfer. */
  template <typename T> void set_arg(JobArgumentList &a, Local<T> t) {
    a.set_local();
    set_arg(a, t.value);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template <typename T> void set_arg(JobArgumentList &a, OutOnly<T> t) {
    a.unset_to_device();
    set_arg(a, t.value);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template <typename T> void set_arg(JobArgumentList &a, InOnly<T> t) {
    a.unset_from_device();
    set_arg(a, t.value);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template <typename T> void set_arg(JobArgumentList &a, Offset<T> t) {
    a.set_offset(t.offset);
    set_arg(a, t.value);
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template <typename T> void set_arg(JobArgumentList &a, WrappedPointer<T> t) {
    a.memop((uint8_t *)t.value, t.sz);
  }

  template <typename T> void set_args(JobArgumentList &a, T &t) {
    set_arg(a, t);
  }

  /** Variadic: recursively sets all given arguments. **/
  template <typename T, typename... Targs>
  void set_args(JobArgumentList &a, T &t, Targs... args) {
    set_arg(a, t);
    set_args(a, args...);
  }
  /* Setters for register values @} */

  TapascoDriver driver_internal;
  TapascoDevice device_internal;
  TapascoMemory default_memory_internal;
};

} /* namespace tapasco */

#endif /* TAPASCO_HPP__ */
