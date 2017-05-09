//
// Copyright (C) 2015 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file 	tpc_api.hpp
//! @brief	Primitive C++ wrapper class for TPC API: Simplifies calls to
//!		FPG and handling of device memory, jobs, etc.
//! @authors 	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @version 	1.2
//! @copyright  Copyright 2015 J. Korinth, TU Darmstadt
//!
//!		This file is part of ThreadPoolComposer (TPC).
//!
//!  		ThreadPoolComposer is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		ThreadPoolComposer is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with ThreadPoolComposer.  If not, see
//!		<http://www.gnu.org/licenses/>.
//! @details	### Change Log ###
//!		- 03/2016 Version 1.2 (jk)
//!		  + added compiler check: header requires g++ >= 5.x.x
//!		- 02/2016 Version 1.2 (jk)
//!               + renamed class to 'ThreadPoolComposer' instead of 'TPC' acro
//!		  + removed rpr namespace
//!		  + moved device id to class instance member (instead of type)
//!		  + new async_launch* methods return futures
//!               + non-critical code uses exceptions for error handling
//!		  + correct copy semantics for const/non-const args
//!               + new type OutOnly<T> as wrapper for output only args
//!		  + using static_assert for type traits instead of assert
//!		  + using is_trivially_copyable instead of pod type trait
//!		  + added constness to most methods
//!               + added compile-time flag TPC_COPY_MT to use multi-threaded
//!                 data transfers (based on std::future + async)
//!		- 10/2015 Version 1.1 (jk)
//!		  + updated to TPC API 1.1
//!		  + several minor improvements (error handling, copying)
//!		- 08/2015 Version 1.0 (jk) 
//!		  + initial prototype version
//!
#ifndef __TPC_API_HPP__
#define __TPC_API_HPP__

#ifndef __clang__
#if __GNUC__ && __GNUC__< 5
  #error "g++ 5.x.x or newer required (C++11 features)"
#endif
#endif

#include <tpc_api.h>
#include <type_traits>
#include <stdexcept>
#include <future>

using namespace std;

/* set this argument to add multithreaded copies instead of sequential copies in
 * set_args during launch calls; performance depends on platform and application */
// #define TPC_COPY_MT  1

#ifdef TPC_COPY_MT
#include <vector>
#endif

namespace tpc {

/**
 * Type annotation for TPC launch argument pointers: output only, i.e., only copy
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
 * C++ Wrapper class for TPC API. Currently wraps a single device.
 **/
struct ThreadPoolComposer {
  /**
   * Constructor. Initializes device by default.
   * Note: Need to check is_ready if using auto-initialization before use.
   * @param initialize initializes TPC during constructor (may throw exception!)
   * @param dev_id device id of this instance (default: 0)
   **/
  ThreadPoolComposer(bool const initialize = true, tpc_dev_id_t const dev_id = 0) {
    if (initialize) init(dev_id);
  }

  /**
   * Destructor. Closes and releases device.
   **/
  virtual ~ThreadPoolComposer() {
    if (_ok) {
      tpc_destroy_device(ctx, dev_ctx);
      tpc_deinit(ctx);
    }
  }

  /** A TPC runtime error. **/
  class tpc_error : public runtime_error {
  public:
    explicit tpc_error (const string& msg) : runtime_error(msg) {}
    explicit tpc_error (const char* msg) : runtime_error(msg) {}
    explicit tpc_error (const tpc_res_t result) : runtime_error(tpc_strerror(result)) {}
  };

  /**
   * Global and device context initialization.
   * @param  dev_id device id
   * @throws tpc_error, if initialization failed
   **/
  void init(tpc_dev_id_t const dev_id)
  {
    tpc_res_t r = tpc_init(&ctx);
    if (r != TPC_SUCCESS)
      throw tpc_error(r);
    if ((r = tpc_create_device(ctx, dev_id, &dev_ctx, TPC_DEVICE_CREATE_FLAGS_NONE)) != TPC_SUCCESS)
      throw tpc_error(r);
    _ok = true;
  }

  /** Returns true, if initialization was successful and device is ready. **/
  bool is_ready() const noexcept { return _ok; }

  /**
   * Launches a job on the device and returns the result.
   * @param f_id Kernel ID.
   * @param ret Reference to return value (output).
   * @param args... Parameters for launch.
   * @return TPC_SUCCESS if launch completed successfully, TPC_FAILURE otherwise.
   **/
  template<typename R, typename... Targs>
  tpc_res_t launch(tpc_func_id_t const f_id, R& ret, Targs... args) const noexcept
  {
    tpc_res_t res;
    // get a job id
    tpc_job_id_t j_id = tpc_device_acquire_job_id(dev_ctx, f_id,
        TPC_DEVICE_ACQUIRE_JOB_ID_BLOCKING);

#ifdef TPC_COPY_MT
    vector<future<tpc_res_t> > fs { r_set_args(j_id, 0, args...) };
    for (auto& f : fs)
      if ((res = f.get()) != TPC_SUCCESS) return res;
#else
    if ((res = set_args(j_id, 0, args...)) != TPC_SUCCESS) return res;
#endif
    if ((res = tpc_device_job_launch(dev_ctx, j_id, TPC_DEVICE_JOB_LAUNCH_BLOCKING)) != TPC_SUCCESS) return res;
    if ((res = tpc_device_job_get_return(dev_ctx, j_id, sizeof(ret), &ret)) != TPC_SUCCESS) return res;
#ifdef TPC_COPY_MT
    fs.clear();
    fs = r_get_args(j_id, 0, args...);
    for (auto& f : fs)
      if ((res = f.get()) != TPC_SUCCESS) return res;
#else
    if ((res = get_args(j_id, 0, args...)) != TPC_SUCCESS) return res;
#endif

    // release job id
    tpc_device_release_job_id(dev_ctx, j_id);
    return res;
  }
  
  /**
   * Launches a job on the device and returns a future to the result.
   * @param f_id Kernel ID.
   * @param ret Reference to return value (output).
   * @param args... Parameters for launch.
   * @return future with value TPC_SUCCESS if launch completed successfully, TPC_FAILURE otherwise.
   **/
  template<typename R, typename... Targs>
  future<tpc_res_t> async_launch(tpc_func_id_t const f_id, R& ret, Targs... args) const noexcept
  {
    return async(std::launch::async, [=, &ret]{ return launch(f_id, ret, args...); });
  }
  
  /**
   * Launches a job on the device without return value.
   * @param f_id Kernel ID.
   * @param args... Parameters for launch.
   * @return TPC_SUCCESS if launch completed successfully, TPC_FAILURE otherwise.
   **/
  template<typename... Targs>
  tpc_res_t launch_no_return(tpc_func_id_t const f_id, Targs... args) const noexcept
  {
    tpc_res_t res;
    // get a job id
    tpc_job_id_t j_id = tpc_device_acquire_job_id(dev_ctx, f_id,
        TPC_DEVICE_ACQUIRE_JOB_ID_BLOCKING);

#ifdef TPC_COPY_MT
    vector<future<tpc_res_t> > fs { r_set_args(j_id, 0, args...) };
    for (auto& f : fs)
      if ((res = f.get()) != TPC_SUCCESS) return res;
#else
    if ((res = set_args(j_id, 0, args...)) != TPC_SUCCESS) return res;
#endif
    if ((res = tpc_device_job_launch(dev_ctx, j_id, TPC_DEVICE_JOB_LAUNCH_BLOCKING)) != TPC_SUCCESS) return res;
#ifdef TPC_COPY_MT
    fs.clear();
    fs = r_get_args(j_id, 0, args...);
    for (auto& f : fs)
      if ((res = f.get()) != TPC_SUCCESS) return res;
#else
    if ((res = get_args(j_id, 0, args...)) != TPC_SUCCESS) return res;
#endif

    // release job id
    tpc_device_release_job_id(dev_ctx, j_id);
    return res;
  }

  /**
   * Launches a job on the device without return value and returns a future to the result.
   * @param f_id Kernel ID.
   * @param args... Parameters for launch.
   * @return future with value TPC_SUCCESS if launch completed successfully, TPC_FAILURE otherwise.
   **/
  template<typename... Targs>
  future<tpc_res_t> async_launch_no_return(tpc_func_id_t const f_id, Targs... args) const noexcept
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
  tpc_res_t alloc(tpc_handle_t &h, size_t const len, tpc_device_alloc_flag_t const flags) const noexcept
  {
    return tpc_device_alloc(dev_ctx, &h, len, flags);
  }

  /**
   * Frees a previously allocated chunk of device memory.
   * @param handle memory chunk handle returned by @see alloc
   **/
  void free(tpc_handle_t const handle, tpc_device_alloc_flag_t const flags) const noexcept
  {
    tpc_device_free(dev_ctx, handle, flags);
  }

  /**
   * Copys memory from main memory to the FPGA device.
   * @param src source address
   * @param dst destination device handle (prev. alloc'ed with tpc_alloc)
   * @param len number of bytes to copy
   * @param flags	flags for copy operation, e.g., TPC_COPY_NONBLOCKING
   * @return TPC_SUCCESS if copy was successful, TPC_FAILURE otherwise
   **/
  tpc_res_t copy_to(void const *src, tpc_handle_t dst, size_t len, tpc_device_copy_flag_t const flags) const noexcept
  {
    return tpc_device_copy_to(dev_ctx, src, dst, len, flags);
  }

  /**
   * Copys memory from FPGA device memory to main memory.
   * @param src source device handle (prev. alloc'ed with tpc_alloc)
   * @param dst destination address
   * @param len number of bytes to copy
   * @param flags flags for copy operation, e.g., TPC_DEVICE_COPY_NONBLOCKING
   * @return TPC_SUCCESS if copy was successful, TPC_FAILURE otherwise
   **/
  tpc_res_t copy_from(tpc_handle_t src, void *dst, size_t len, tpc_device_copy_flag_t const flags) const noexcept
  {
    return tpc_device_copy_from(dev_ctx, src, dst, len, flags);
  }

  /**
   * Returns the number of instances of function func_id in the currently
   * loaded bitstream.
   * @param func_id function id
   * @return number of instances > 0 if function is instantiated in the
   *         bitstream, 0 if function is unavailable
   **/
  uint32_t func_instance_count(tpc_func_id_t const func_id) const noexcept
  {
    return tpc_device_func_instance_count(dev_ctx, func_id);
  }

private:
  /** Sets a single value argument. **/
  template<typename T>
  tpc_res_t set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T const t) const noexcept
  {
    // only 32/64bit values can be passed directly (i.e., via register)
    if (sizeof(T) > 8)  // TODO remove magic number?
      return set_args(j_id, arg_idx, &t);
    else
      return tpc_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(t), &t);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template<typename T>
  tpc_res_t set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, OutOnly<T> t) const noexcept
  {
    tpc_handle_t h { 0 };
    tpc_res_t r;
    if ((r = tpc_device_alloc(dev_ctx, &h, sizeof(*t.value), TPC_DEVICE_ALLOC_FLAGS_NONE)) != TPC_SUCCESS) return r;
    return tpc_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template<typename T>
  tpc_res_t set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tpc_handle_t h { 0 };
    tpc_res_t r;
    if ((r = tpc_device_alloc(dev_ctx, &h, sizeof(*t), TPC_DEVICE_ALLOC_FLAGS_NONE)) != TPC_SUCCESS) return r;
    if ((r = tpc_device_copy_to(dev_ctx, t, h, sizeof(*t), TPC_DEVICE_COPY_BLOCKING)) != TPC_SUCCESS) return r;
    return tpc_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

  /** Sets a single const pointer argument (alloc + copy). **/
  template<typename T>
  tpc_res_t set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, const T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tpc_handle_t h { 0 };
    tpc_res_t r;
    if ((r = tpc_device_alloc(dev_ctx, &h, sizeof(*t), TPC_DEVICE_ALLOC_FLAGS_NONE)) != TPC_SUCCESS) return r;
    if ((r = tpc_device_copy_to(dev_ctx, t, h, sizeof(*t), TPC_DEVICE_COPY_BLOCKING)) != TPC_SUCCESS) return r;
    return tpc_device_job_set_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h);
  }

#ifdef TPC_COPY_MT
  /** Variadic: recursively wraps setting all given arguments in vector of futures. **/
  template<typename... Targs>
  vector<future<tpc_res_t> > r_set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, Targs... args) const noexcept
  {
    vector<future<tpc_res_t> > fs;
    set_args(fs, j_id, arg_idx, args...);
    return fs;
  }

  /** Variadic: recursively sets all given arguments. **/
  template<typename T, typename... Targs>
  void set_args(vector<future<tpc_res_t> >& fs, tpc_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return set_args(j_id, arg_idx, t); }));
    set_args(fs, j_id, arg_idx + 1, args...);
  }
  /** Recursion leaf. **/
  template<typename T>
  void set_args(vector<future<tpc_res_t> >& fs, tpc_job_id_t const j_id, uint32_t const arg_idx, T t) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return set_args(j_id, arg_idx, t); }));
  }
#else
  /** Variadic: recursively sets all given arguments. **/
  template<typename T, typename... Targs>
  tpc_res_t set_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    tpc_res_t r;
    if ((r = set_args(j_id, arg_idx, t)) != TPC_SUCCESS) return r;
    return set_args(j_id, arg_idx + 1, args...);
  }
#endif

  /** Gets a single value argument. **/
  template<typename T>
  tpc_res_t get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T const t) const noexcept {
    return TPC_SUCCESS;
  }

  /** Gets a single output-only argument (copy + dealloc). **/
  template<typename T>
  tpc_res_t get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, OutOnly<T> t) const noexcept {
    return get_args(j_id, arg_idx, t.value);
  }

  /** Gets a single pointer argument (copy + dealloc). **/
  template<typename T>
  tpc_res_t get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tpc_handle_t h;
    tpc_res_t r;
    if ((r = tpc_device_job_get_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h)) != TPC_SUCCESS) return r;
    if ((r = tpc_device_copy_from(dev_ctx, h, (void *)t, sizeof(*t), TPC_DEVICE_COPY_BLOCKING)) != TPC_SUCCESS) return r;
    tpc_device_free(dev_ctx, h, TPC_DEVICE_ALLOC_FLAGS_NONE);
    return TPC_SUCCESS;
  }
  
  /** Gets a single const pointer argument (dealloc only). **/
  template<typename T>
  tpc_res_t get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T const* t) const noexcept
  {
    static_assert(is_trivially_copyable<T>::value, "Types must be trivially copyable!");
    tpc_handle_t h;
    tpc_res_t r;
    if ((r = tpc_device_job_get_arg(dev_ctx, j_id, arg_idx, sizeof(h), &h)) != TPC_SUCCESS) return r;
    tpc_device_free(dev_ctx, h, TPC_DEVICE_ALLOC_FLAGS_NONE);
    return TPC_SUCCESS;
  }

#ifdef TPC_COPY_MT
  /** Variadic: recursively wraps getting all given arguments in vector of futures. **/
  template<typename... Targs>
  vector<future<tpc_res_t> > r_get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, Targs... args) const noexcept
  {
    vector<future<tpc_res_t> > fs;
    get_args(fs, j_id, arg_idx, args...);
    return fs;
  }

  /** Variadic: recursively gets all given arguments. **/
  template<typename T, typename... Targs>
  void get_args(vector<future<tpc_res_t> >& fs, tpc_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return get_args(j_id, arg_idx, t); }));
    get_args(fs, j_id, arg_idx + 1, args...);
  }
  /** Recursion leaf. **/
  template<typename T>
  void get_args(vector<future<tpc_res_t> >& fs, tpc_job_id_t const j_id, uint32_t const arg_idx, T t) const noexcept
  {
    fs.push_back(async(std::launch::async, [&]{ return get_args(j_id, arg_idx, t); }));
  }
#else
  /** Variadic: recursively gets all given arguments. **/
  template<typename T, typename... Targs>
  tpc_res_t get_args(tpc_job_id_t const j_id, uint32_t const arg_idx, T t, Targs... args) const noexcept
  {
    tpc_res_t r;
    if ((r = get_args(j_id, arg_idx, t)) != TPC_SUCCESS) return r;
    return get_args(j_id, arg_idx + 1, args...);
  }
#endif
  
  bool _ok { false };
  tpc_ctx_t* ctx { nullptr };
  tpc_dev_ctx_t* dev_ctx { nullptr };
};

} /* namespace tpc */

#endif /* __TPC_API_HPP__ */
