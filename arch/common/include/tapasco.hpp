//
// Copyright (C) 2015 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file 	tapasco.hpp
//! @brief	Primitive C++ wrapper class for TAPASCO API: Simplifies calls to
//!		FPG and handling of device memory, jobs, etc.
//! @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @version 	1.2
//! @copyright  Copyright 2015 J. Korinth, TU Darmstadt
//!
//!		This file is part of Tapasco (TAPASCO).
//!
//!  		Tapasco is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		Tapasco is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with Tapasco.  If not, see
//!		<http://www.gnu.org/licenses/>.
//! @details	### Change Log ###
//!		- 03/2016 Version 1.3 (jk)
//!		  + added device capabilities
//!		- 03/2016 Version 1.2.1 (jk)
//!		  + renamed to 'tapasco.hpp'
//!		- 03/2016 Version 1.2 (jk)
//!		  + added compiler check: header requires g++ >= 5.x.x
//!		- 02/2016 Version 1.2 (jk)
//!               + renamed class to 'Tapasco' instead of 'TAPASCO' acro
//!		  + removed rpr namespace
//!		  + moved device id to class instance member (instead of type)
//!		  + new async_launch* methods return futures
//!               + non-critical code uses exceptions for error handling
//!		  + correct copy semantics for const/non-const args
//!               + new type OutOnly<T> as wrapper for output only args
//!		  + using static_assert for type traits instead of assert
//!		  + using is_trivially_copyable instead of pod type trait
//!		  + added constness to most methods
//!               + added compile-time flag TAPASCO_COPY_MT to use multi-threaded
//!                 data transfers (based on std::future + async)
//!		- 10/2015 Version 1.1 (jk)
//!		  + updated to TAPASCO API 1.1
//!		  + several minor improvements (error handling, copying)
//!		- 08/2015 Version 1.0 (jk) 
//!		  + initial prototype version
//!
#ifndef TAPASCO_HPP__
#define TAPASCO_HPP__

#ifndef __clang__
#if __GNUC__ && __GNUC__< 5
  #error "g++ 5.x.x or newer required (C++11 features)"
#endif
#endif

#include <tapasco.h>
#include <type_traits>
#include <stdexcept>
#include <future>

using namespace std;

/* set this argument to add multithreaded copies instead of sequential copies in
 * set_args during launch calls; performance depends on platform and application */
// #define TAPASCO_COPY_MT  1

#ifdef TAPASCO_COPY_MT
#include <vector>
#endif

namespace tapasco {

/**
 * Type annotation for TAPASCO launch argument pointers: output only, i.e., only copy
 * from device to host after execution, don't copy from host to device prior.
 * The other two possibilities (input-only, in-and-out/reference) can be expressed
 * via the type system (const vs. non-const), but this use pattern requires a
 * wrapping into an new type (could later be replaced by an annotation).
 **/
template<typename T>
struct OutOnly final {
  OutOnly(T*  value) : value(value) {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
  }
  T* value;
};

/**
 * C++ Wrapper class for TaPaSCo API. Currently wraps a single device.
 **/
struct Tapasco {
  /**
   * Constructor. Initializes device by default.
   * Note: Need to check is_ready if using auto-initialization before use.
   * @param initialize initializes TAPASCO during constructor (may throw exception!)
   * @param dev_id device id of this instance (default: 0)
   **/
  Tapasco(bool const initialize = true, tapasco_dev_id_t const dev_id = 0) {
    if (initialize) init(dev_id);
  }

  /**
   * Destructor. Closes and releases device.
   **/
  virtual ~Tapasco() {
    if (_ok) {
      tapasco_destroy_device(ctx, dev_ctx);
      tapasco_deinit(ctx);
    }
  }

  /** A TAPASCO runtime error. **/
  class tapasco_error : public runtime_error {
  public:
    explicit tapasco_error (const string& msg) : runtime_error(msg) {}
    explicit tapasco_error (const char* msg) : runtime_error(msg) {}
    explicit tapasco_error (const tapasco_res_t result) : runtime_error(tapasco_strerror(result)) {}
  };

  /**
   * Global and device context initialization.
   * @param  dev_id device id
   * @throws tapasco_error, if initialization failed
   **/
  void init(tapasco_dev_id_t const dev_id)
  {
    tapasco_res_t r = tapasco_init(&ctx);
    if (r != TAPASCO_SUCCESS)
      throw tapasco_error(r);
    if ((r = tapasco_create_device(ctx, dev_id, &dev_ctx, TAPASCO_DEVICE_CREATE_FLAGS_NONE)) != TAPASCO_SUCCESS)
      throw tapasco_error(r);
    _ok = true;
  }

  /** Returns true, if initialization was successful and device is ready. **/
  bool is_ready() const noexcept { return _ok; }

  /**
   * Launches a job on the device and returns the result.
   * @param f_id Kernel ID.
   * @param ret Reference to return value (output).
   * @param args... Parameters for launch.
   * @return TAPASCO_SUCCESS if launch completed successfully, TAPASCO_FAILURE otherwise.
   **/
  template<typename R, typename... Targs>
  tapasco_res_t launch(tapasco_func_id_t const f_id, R& ret, Targs... args) const noexcept
  {
    tapasco_res_t res;
    // get a job id
    tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev_ctx, f_id,
        TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING);

#ifdef TAPASCO_COPY_MT
    vector<future<tapasco_res_t> > fs { r_set_args(j_id, 0, args...) };
    for (auto& f : fs)
      if ((res = f.get()) != TAPASCO_SUCCESS) return res;
#else
    if ((res = set_args(j_id, 0, args...)) != TAPASCO_SUCCESS) return res;
#endif
    if ((res = tapasco_device_job_launch(dev_ctx, j_id, TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING)) != TAPASCO_SUCCESS) return res;
    if ((res = tapasco_device_job_get_return(dev_ctx, j_id, sizeof(ret), &ret)) != TAPASCO_SUCCESS) return res;
#ifdef TAPASCO_COPY_MT
    fs.clear();
    fs = r_get_args(j_id, 0, args...);
    for (auto& f : fs)
      if ((res = f.get()) != TAPASCO_SUCCESS) return res;
#else
    if ((res = get_args(j_id, 0, args...)) != TAPASCO_SUCCESS) return res;
#endif

    // release job id
    tapasco_device_release_job_id(dev_ctx, j_id);
    return res;
  }

  /**
   * Launches a job on the device and returns a future to the result.
   * @param f_id Kernel ID.
   * @param ret Reference to return value (output).
   * @param args... Parameters for launch.
   * @return future with value TAPASCO_SUCCESS if launch completed successfully, TAPASCO_FAILURE otherwise.
   **/
  template<typename R, typename... Targs>
  future<tapasco_res_t> async_launch(tapasco_func_id_t const f_id, R& ret, Targs... args) const noexcept
  {
    return async(std::launch::async, [=, &ret]{ return launch(f_id, ret, args...); });
  }

  /**
   * Launches a job on the device without return value.
   * @param f_id Kernel ID.
   * @param args... Parameters for launch.
   * @return TAPASCO_SUCCESS if launch completed successfully, TAPASCO_FAILURE otherwise.
   **/
  template<typename... Targs>
  tapasco_res_t launch_no_return(tapasco_func_id_t const f_id, Targs... args) const noexcept
  {
    tapasco_res_t res;
    // get a job id
    tapasco_job_id_t j_id = tapasco_device_acquire_job_id(dev_ctx, f_id,
        TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING);

#ifdef TAPASCO_COPY_MT
    vector<future<tapasco_res_t> > fs { r_set_args(j_id, 0, args...) };
    for (auto& f : fs)
      if ((res = f.get()) != TAPASCO_SUCCESS) return res;
#else
    if ((res = set_args(j_id, 0, args...)) != TAPASCO_SUCCESS) return res;
#endif
    if ((res = tapasco_device_job_launch(dev_ctx, j_id, TAPASCO_DEVICE_JOB_LAUNCH_BLOCKING)) != TAPASCO_SUCCESS) return res;
#ifdef TAPASCO_COPY_MT
    fs.clear();
    fs = r_get_args(j_id, 0, args...);
    for (auto& f : fs)
      if ((res = f.get()) != TAPASCO_SUCCESS) return res;
#else
    if ((res = get_args(j_id, 0, args...)) != TAPASCO_SUCCESS) return res;
#endif

    // release job id
    tapasco_device_release_job_id(dev_ctx, j_id);
    return res;
  }

  /**
   * Launches a job on the device without return value and returns a future to the result.
   * @param f_id Kernel ID.
   * @param args... Parameters for launch.
   * @return future with value TAPASCO_SUCCESS if launch completed successfully, TAPASCO_FAILURE otherwise.
   **/
  template<typename... Targs>
  future<tapasco_res_t> async_launch_no_return(tapasco_func_id_t const f_id, Targs... args) const noexcept
  {
    return async(std::launch::async, [=]{ return launch_no_return(f_id, args...); });
  }

  /**
   * Allocates a chunk of len bytes on the device.
   * @param len size in bytes
   * @param h output parameter for handle
   * @param flags device memory allocation flags
   * @return handle > 0 if successful, 0 otherwise
   **/
  tapasco_res_t alloc(tapasco_handle_t &h, size_t const len, tapasco_device_alloc_flag_t const flags) const noexcept
  {
    return tapasco_device_alloc(dev_ctx, &h, len, flags);
  }

  /**
   * Frees a previously allocated chunk of device memory.
   * @param handle memory chunk handle returned by @see alloc
   **/
  void free(tapasco_handle_t const handle, tapasco_device_alloc_flag_t const flags) const noexcept
  {
    tapasco_device_free(dev_ctx, handle, flags);
  }

  /**
   * Copys memory from main memory to the FPGA device.
   * @param src source address
   * @param dst destination device handle (prev. alloc'ed with tapasco_alloc)
   * @param len number of bytes to copy
   * @param flags	flags for copy operation, e.g., TAPASCO_COPY_NONBLOCKING
   * @return TAPASCO_SUCCESS if copy was successful, TAPASCO_FAILURE otherwise
   **/
  tapasco_res_t copy_to(void const *src, tapasco_handle_t dst, size_t len, tapasco_device_copy_flag_t const flags) const noexcept
  {
    return tapasco_device_copy_to(dev_ctx, src, dst, len, flags);
  }

  /**
   * Copys memory from FPGA device memory to main memory.
   * @param src source device handle (prev. alloc'ed with tapasco_alloc)
   * @param dst destination address
   * @param len number of bytes to copy
   * @param flags flags for copy operation, e.g., TAPASCO_DEVICE_COPY_NONBLOCKING
   * @return TAPASCO_SUCCESS if copy was successful, TAPASCO_FAILURE otherwise
   **/
  tapasco_res_t copy_from(tapasco_handle_t src, void *dst, size_t len, tapasco_device_copy_flag_t const flags) const noexcept
  {
    return tapasco_device_copy_from(dev_ctx, src, dst, len, flags);
  }

  /**
   * Returns the number of instances of function func_id in the currently
   * loaded bitstream.
   * @param func_id function id
   * @return number of instances > 0 if function is instantiated in the
   *         bitstream, 0 if function is unavailable
   **/
  uint32_t func_instance_count(tapasco_func_id_t const func_id) const noexcept
  {
    return tapasco_device_func_instance_count(dev_ctx, func_id);
  }

  /**
   * Checks if the current bitstream supports a given capability.
   * @param cap capability to check
   * @return TAPASCO_SUCCESS, if capability is available, TAPASCO_FAILURE otherwise
   **/
  tapasco_res_t has_capability(tapasco_device_capability_t cap) const noexcept
  {
    return tapasco_device_has_capability(dev_ctx, cap);
  }

private:
  /** Sets a single value argument. **/
  template<typename T>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T const t) const noexcept
  {
    // only 32/64bit values can be passed directly (i.e., via register)
    if (sizeof(T) > 8)  // TODO remove magic number?
      return set_args(j_id, arg_idx, &t);
    else
      return tapasco_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(t), &t);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template<typename T>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, OutOnly<T> t) const noexcept
  {
    tapasco_handle_t h { 0 };
    tapasco_res_t r;
    if ((r = tapasco_device_alloc(dev_ctx, &h, sizeof(*t.value), TAPASCO_DEVICE_ALLOC_FLAGS_NONE)) != TAPASCO_SUCCESS) return r;
    return tapasco_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template<typename T>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tapasco_handle_t h { 0 };
    tapasco_res_t r;
    if ((r = tapasco_device_alloc(dev_ctx, &h, sizeof(*t), TAPASCO_DEVICE_ALLOC_FLAGS_NONE)) != TAPASCO_SUCCESS) return r;
    if ((r = tapasco_device_copy_to(dev_ctx, t, h, sizeof(*t), TAPASCO_DEVICE_COPY_BLOCKING)) != TAPASCO_SUCCESS) return r;
    return tapasco_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

  /** Sets a single const pointer argument (alloc + copy). **/
  template<typename T>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, const T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tapasco_handle_t h { 0 };
    tapasco_res_t r;
    if ((r = tapasco_device_alloc(dev_ctx, &h, sizeof(*t), TAPASCO_DEVICE_ALLOC_FLAGS_NONE)) != TAPASCO_SUCCESS) return r;
    if ((r = tapasco_device_copy_to(dev_ctx, t, h, sizeof(*t), TAPASCO_DEVICE_COPY_BLOCKING)) != TAPASCO_SUCCESS) return r;
    return tapasco_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

#ifdef TAPASCO_COPY_MT
  /** Variadic: recursively wraps setting all given arguments in vector of futures. **/
  template<typename... Targs>
  vector<future<tapasco_res_t> > r_set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, Targs... args) const noexcept
  {
    vector<future<tapasco_res_t> > fs;
    set_args(fs, j_id, arg_idx, args...);
    return fs;
  }

  /** Variadic: recursively sets all given arguments. **/
  template<typename T, typename... Targs>
  void set_args(vector<future<tapasco_res_t> >& fs, tapasco_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return set_args(j_id, arg_idx, t); }));
    set_args(fs, j_id, arg_idx + 1, args...);
  }
  /** Recursion leaf. **/
  template<typename T>
  void set_args(vector<future<tapasco_res_t> >& fs, tapasco_job_id_t const j_id, uint32_t const arg_idx, T t) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return set_args(j_id, arg_idx, t); }));
  }
#else
  /** Variadic: recursively sets all given arguments. **/
  template<typename T, typename... Targs>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    tapasco_res_t r;
    if ((r = set_args(j_id, arg_idx, t)) != TAPASCO_SUCCESS) return r;
    return set_args(j_id, arg_idx + 1, args...);
  }
#endif

  /** Gets a single value argument. **/
  template<typename T>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T const t) const noexcept {
    return TAPASCO_SUCCESS;
  }

  /** Gets a single output-only argument (copy + dealloc). **/
  template<typename T>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, OutOnly<T> t) const noexcept {
    return get_args(j_id, arg_idx, t.value);
  }

  /** Gets a single pointer argument (copy + dealloc). **/
  template<typename T>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tapasco_handle_t h;
    tapasco_res_t r;
    if ((r = tapasco_device_job_get_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h)) != TAPASCO_SUCCESS) return r;
    if ((r = tapasco_device_copy_from(dev_ctx, h, (void *)t, sizeof(*t), TAPASCO_DEVICE_COPY_BLOCKING)) != TAPASCO_SUCCESS) return r;
    tapasco_device_free(dev_ctx, h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return TAPASCO_SUCCESS;
  }

  /** Gets a single const pointer argument (dealloc only). **/
  template<typename T>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T const* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tapasco_handle_t h;
    tapasco_res_t r;
    if ((r = tapasco_device_job_get_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h)) != TAPASCO_SUCCESS) return r;
    tapasco_device_free(dev_ctx, h, TAPASCO_DEVICE_ALLOC_FLAGS_NONE);
    return TAPASCO_SUCCESS;
  }

#ifdef TAPASCO_COPY_MT
  /** Variadic: recursively wraps getting all given arguments in vector of futures. **/
  template<typename... Targs>
  vector<future<tapasco_res_t> > r_get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, Targs... args) const noexcept
  {
    vector<future<tapasco_res_t> > fs;
    get_args(fs, j_id, arg_idx, args...);
    return fs;
  }

  /** Variadic: recursively gets all given arguments. **/
  template<typename T, typename... Targs>
  void get_args(vector<future<tapasco_res_t> >& fs, tapasco_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return get_args(j_id, arg_idx, t); }));
    get_args(fs, j_id, arg_idx + 1, args...);
  }
  /** Recursion leaf. **/
  template<typename T>
  void get_args(vector<future<tapasco_res_t> >& fs, tapasco_job_id_t const j_id, uint32_t const arg_idx, T t) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return get_args(j_id, arg_idx, t); }));
  }
#else
  /** Variadic: recursively gets all given arguments. **/
  template<typename T, typename... Targs>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    tapasco_res_t r;
    if ((r = get_args(j_id, arg_idx, t)) != TAPASCO_SUCCESS) return r;
    return get_args(j_id, arg_idx + 1, args...);
  }
#endif

  bool _ok { false };
  tapasco_ctx_t* ctx { nullptr };
  tapasco_dev_ctx_t* dev_ctx { nullptr };
};

} /* namespace tapasco */

#endif /* TAPASCO_HPP__ */
