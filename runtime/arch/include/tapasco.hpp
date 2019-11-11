//! @file   tapasco.hpp
//! @brief  C++ wrapper class for TAPASCO API: Simplifies calls to
//!   FPGA and handling of device memory, jobs, etc.
//! @authors  J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @version  1.6
//! @copyright  Copyright 2015-2018 J. Korinth, TU Darmstadt
//!
//!   This file is part of Tapasco (TaPaSCo).
//!
//!     Tapasco is free software: you can redistribute it
//!   and/or modify it under the terms of the GNU Lesser General
//!   Public License as published by the Free Software Foundation,
//!   either version 3 of the License, or (at your option) any later
//!   version.
//!
//!     Tapasco is distributed in the hope that it will be
//!   useful, but WITHOUT ANY WARRANTY; without even the implied
//!   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!   See the GNU Lesser General Public License for more details.
//!
//!     You should have received a copy of the GNU Lesser General Public
//!   License along with Tapasco.  If not, see
//!   <http://www.gnu.org/licenses/>.
//!
#ifndef TAPASCO_HPP__
#define TAPASCO_HPP__

#ifndef __clang__
#if __GNUC__ && __GNUC__ < 5
#error "g++ 5.x.x or newer required (C++11 features)"
#endif
#endif

extern "C" {
#include <platform.h>
#include <tapasco.h>
#include <tapasco_context.h>
#include <tapasco_device.h>
}
#include <cstdint>
#include <functional>
#include <future>
#include <iostream>
#include <stdexcept>
#include <type_traits>

using namespace std;

namespace tapasco {
using job_future = std::function<tapasco_res_t(void)>;

/**
 * Type annotation for TAPASCO launch argument pointers: output only, i.e., only
 *copy from device to host after execution, don't copy from host to device
 *prior.
 **/
template <typename T> struct OutOnly final {
  OutOnly(T &value) : value(value) {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
  }
  T &value;
};

template <typename T> OutOnly<T> makeOutOnly(T &t) { return OutOnly<T>(t); }

/**
 * Type annotation for TAPASCO launch argument pointers: input only, i.e., only
 *copy from host to device before execution. This behaviour might be realised
 *using const vs non-const types but the behaviour of const was not not as clear
 *to a user as it should be which leads to unwanted transfers.
 **/
template <typename T> struct InOnly final {
  InOnly(T &value) : value(value) {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
  }
  T &value;
};

template <typename T> InOnly<T> makeInOnly(T &t) { return InOnly<T>(t); }

/**
 * Type annotation for Tapasco launch argument pointers: If the first argument
 * supplied to launch is wrapped in this type, it is assumed to be the function
 * return value residing in the return register and its value will be copied
 * from the return value register to the pointee after execution finishes.
 **/
template <typename T> struct RetVal final {
  RetVal(T &value) : value(value) {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
  }
  T &value;
};

/**
 * Type annotation for Tapasco launch argument pointers: If possible, data
 * should be placed in PE-local memory (faster access).
 **/
template <typename T> struct Local final {
  Local(T &value) : value(value) {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
  }
  T &value;
};

template <typename T> Local<T> makeLocal(T &t) { return Local<T>(t); }

/**
 * Wrapped pointer type that can be used to transfer memory areas from and to a
 *device.
 **/
template <typename T> struct WrappedPointer final {
  WrappedPointer(T *value, size_t sz) : value(value), sz(sz) {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
  }
  T *value;
  size_t sz;
};

template <typename T> WrappedPointer<T> makeWrappedPointer(T *t, size_t sz) {
  return WrappedPointer<T>(t, sz);
}

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
  Tapasco(bool const initialize = true,
          tapasco_access_t const access = TAPASCO_EXCLUSIVE_ACCESS,
          tapasco_dev_id_t const dev_id = 0) {
    if (initialize)
      init(access, dev_id);
  }

  /**
   * Destructor. Closes and releases device.
   **/
  virtual ~Tapasco() {
    if (_ok) {
      tapasco_destroy_device(ctx, devctx);
      tapasco_deinit(ctx);
    }
  }

  /** A TAPASCO runtime error. **/
  class tapasco_error : public runtime_error {
  public:
    explicit tapasco_error(const string &msg) : runtime_error(msg) {}
    explicit tapasco_error(const char *msg) : runtime_error(msg) {}
    explicit tapasco_error(const tapasco_res_t result)
        : runtime_error(tapasco_strerror(result)) {}
  };

  /** A Platform runtime error. **/
  class platform_error : public runtime_error {
  public:
    explicit platform_error(const string &msg) : runtime_error(msg) {}
    explicit platform_error(const char *msg) : runtime_error(msg) {}
    explicit platform_error(const platform_res_t result)
        : runtime_error(platform_strerror(result)) {}
  };

  /**
   * Global and device context initialization.
   * @param  dev_id device id
   * @throws tapasco_error, if initialization failed
   **/
  void init(tapasco_access_t const access, tapasco_dev_id_t const dev_id) {
    tapasco_res_t r = tapasco_init(&ctx);
    if (r != TAPASCO_SUCCESS) {
      cerr << "ERROR: failed to initialize tapasco system: "
           << tapasco_strerror(r) << " (" << r << ")" << endl;
      throw tapasco_error(r);
    }

    tapasco_device_create_flag_t flags = TAPASCO_DEVICE_CREATE_EXCLUSIVE;
    switch (access) {
    case TAPASCO_SHARED_ACCESS:
      flags = TAPASCO_DEVICE_CREATE_SHARED;
      break;
    case TAPASCO_MONITOR_ACCESS:
      flags = TAPASCO_DEVICE_CREATE_MONITOR;
      break;
    default:
      break;
    }

    if ((r = tapasco_create_device(ctx, dev_id, &devctx, flags)) !=
        TAPASCO_SUCCESS) {
      cerr << "ERROR: failed to initialize tapasco device " << dev_id << ": "
           << tapasco_strerror(r) << " (" << r << ")" << endl;
      throw tapasco_error(r);
    }
    _ok = true;
  }

  tapasco_res_t info(platform_info_t *info) const noexcept {
    return tapasco_device_info(devctx, info);
  }

  tapasco_ctx_t *context() const noexcept { return ctx; }
  tapasco_devctx_t *device() const noexcept { return devctx; }
  platform_ctx_t *platform() const noexcept { return ctx->pctx; }
  platform_devctx_t *platform_device() const noexcept { return devctx->pdctx; }

  /** Returns true, if initialization was successful and device is ready. **/
  bool is_ready() const noexcept { return _ok; }

  template <typename R, typename... Targs>
  job_future launch(tapasco_kernel_id_t const k_id, RetVal<R> &ret,
                    Targs... args) noexcept {
    tapasco_job_id_t j_id{0};
    tapasco_res_t res{TAPASCO_SUCCESS};
    auto mkerr = [](tapasco_res_t r) { return [r]() { return r; }; };
    if ((res = tapasco_device_acquire_job_id(
             devctx, &j_id, k_id, TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING)) !=
        TAPASCO_SUCCESS)
      return mkerr(res);
    if ((res = set_args(j_id, 0, args...)) != TAPASCO_SUCCESS)
      return mkerr(res);
    if ((res = tapasco_device_job_launch(
             devctx, j_id, TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING)) !=
        TAPASCO_SUCCESS)
      return mkerr(res);
    return [this, j_id, &ret, &args...]() {
      return collect<R, Targs...>(j_id, ret, args...);
    };
  }

  template <typename... Targs>
  job_future launch(tapasco_kernel_id_t const k_id, Targs... args) noexcept {
    tapasco_job_id_t j_id{0};
    tapasco_res_t res{TAPASCO_SUCCESS};
    auto mkerr = [](tapasco_res_t r) { return [r]() { return r; }; };
    if ((res = tapasco_device_acquire_job_id(
             devctx, &j_id, k_id, TAPASCO_DEVICE_ACQUIRE_JOB_ID_BLOCKING)) !=
        TAPASCO_SUCCESS)
      return mkerr(res);
    if ((res = set_args(j_id, 0, args...)) != TAPASCO_SUCCESS)
      return mkerr(res);
    if ((res = tapasco_device_job_launch(
             devctx, j_id, TAPASCO_DEVICE_JOB_LAUNCH_NONBLOCKING)) !=
        TAPASCO_SUCCESS)
      return mkerr(res);
    return
        [this, j_id, &args...]() { return collect<Targs...>(j_id, args...); };
  }

  /**
   * Allocates a chunk of len bytes on the device.
   * @param len size in bytes
   * @param h output parameter for handle
   * @param flags device memory allocation flags
   * @return TAPASCO_SUCCESS if successful, an error code otherwise.
   **/
  tapasco_res_t alloc(tapasco_handle_t &h, size_t const len,
                      tapasco_device_alloc_flag_t const flags) const noexcept {
    return tapasco_device_alloc(devctx, &h, len, flags);
  }

  /**
   * Frees a previously allocated chunk of device memory.
   * @param handle memory chunk handle returned by @see alloc
   **/
  void free(tapasco_handle_t const handle, size_t const len,
            tapasco_device_alloc_flag_t const flags) const noexcept {
    tapasco_device_free(devctx, handle, len, flags);
  }

  /**
   * Copys memory from main memory to the FPGA device.
   * @param src source address
   * @param dst destination device handle
   * @param len number of bytes to copy
   * @param flags flags for copy operation
   * @return TAPASCO_SUCCESS if copy was successful, an error code otherwise
   **/
  tapasco_res_t copy_to(void const *src, tapasco_handle_t dst, size_t len,
                        tapasco_device_copy_flag_t const flags) const noexcept {
    return tapasco_device_copy_to(devctx, src, dst, len, flags);
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
  tapasco_res_t copy_from(tapasco_handle_t src, void *dst, size_t len,
                          tapasco_device_copy_flag_t const flags) const
      noexcept {
    return tapasco_device_copy_from(devctx, src, dst, len, flags);
  }

  /**
   * Returns the number of PEs of kernel k_id in the currently loaded bitstream.
   * @param k_id kernel id
   * @return number of instances > 0 if kernel is instantiated in the
   *         bitstream, 0 if kernel is unavailable
   **/
  size_t kernel_pe_count(tapasco_kernel_id_t const k_id) const noexcept {
    return tapasco_device_kernel_pe_count(devctx, k_id);
  }

  /**
   * Checks if the current bitstream supports a given capability.
   * @param cap capability to check
   * @return TAPASCO_SUCCESS, if capability is available, an error code
   *otherwise
   **/
  tapasco_res_t has_capability(tapasco_device_capability_t cap) const noexcept {
    return tapasco_device_has_capability(devctx, cap);
  }

private:
  /* @{ Collector methods: bottom half of job launch. */
  /** Waits for the job, fetches data from registers and releases the job
   * (w/return). */
  template <typename R, typename... Targs>
  tapasco_res_t collect(const tapasco_job_id_t j_id, RetVal<R> &ret,
                        Targs... args) noexcept {
    tapasco_res_t res{TAPASCO_SUCCESS};
    if ((res = tapasco_device_job_collect(devctx, j_id)) != TAPASCO_SUCCESS)
      return res;
    if ((res = tapasco_device_job_get_return(devctx, j_id, sizeof(ret.value),
                                             &ret.value)) != TAPASCO_SUCCESS)
      return res;
    if ((res = get_args(j_id, 0, args...)) != TAPASCO_SUCCESS)
      return res;
    tapasco_device_release_job_id(devctx, j_id);
    return res;
  }

  /** Waits for the job, fetches data from registers and releases the job (no
   * return). */
  template <typename... Targs>
  tapasco_res_t collect(const tapasco_job_id_t j_id, Targs... args) noexcept {
    tapasco_res_t res{TAPASCO_SUCCESS};
    if ((res = tapasco_device_job_collect(devctx, j_id)) != TAPASCO_SUCCESS)
      return res;
    if ((res = get_args(j_id, 0, args...)) != TAPASCO_SUCCESS)
      return res;
    tapasco_device_release_job_id(devctx, j_id);
    return res;
  }
  /* Collector methods: bottom half of job launch. @} */

  /* @{ Setters for register values */
  /** Sets a single value argument. **/
  template <typename T>
  tapasco_res_t set_arg(tapasco_job_id_t const j_id, size_t const arg_idx,
                        T t) noexcept {
    // only 32/64bit values can be passed directly (i.e., via register)
    if (sizeof(T) > sizeof(uint64_t))
      return set_arg(j_id, arg_idx, &t);
    else
      return tapasco_device_job_set_arg(devctx, j_id, arg_idx, sizeof(t), &t);
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template <typename T>
  tapasco_res_t set_arg(
      tapasco_job_id_t const j_id, size_t const arg_idx, T *t,
      const tapasco_device_alloc_flag_t flags = TAPASCO_DEVICE_ALLOC_FLAGS_NONE,
      const tapasco_copy_direction_flag_t copy_flags =
          TAPASCO_COPY_DIRECTION_BOTH) noexcept {
    WrappedPointer<T> w = WrappedPointer<T>(t, sizeof(*t));
    return set_arg(j_id, arg_idx, w, flags, copy_flags);
  }

  /** Sets local memory flag for transfer. */
  template <typename T>
  tapasco_res_t set_arg(
      tapasco_job_id_t const j_id, size_t const arg_idx, Local<T> t,
      const tapasco_device_alloc_flag_t flags = TAPASCO_DEVICE_ALLOC_FLAGS_NONE,
      const tapasco_copy_direction_flag_t copy_flags =
          TAPASCO_COPY_DIRECTION_BOTH) noexcept {
    return set_arg(j_id, arg_idx, t.value, TAPASCO_DEVICE_ALLOC_FLAGS_PE_LOCAL,
                   copy_flags);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template <typename T>
  tapasco_res_t set_arg(
      tapasco_job_id_t const j_id, size_t const arg_idx, OutOnly<T> t,
      const tapasco_device_alloc_flag_t flags = TAPASCO_DEVICE_ALLOC_FLAGS_NONE,
      const tapasco_copy_direction_flag_t copy_flags =
          TAPASCO_COPY_DIRECTION_BOTH) noexcept {
    return set_arg(j_id, arg_idx, t.value, flags, TAPASCO_COPY_DIRECTION_FROM);
  }

  /** Sets a single output-only pointer argument (alloc only). **/
  template <typename T>
  tapasco_res_t set_arg(
      tapasco_job_id_t const j_id, size_t const arg_idx, InOnly<T> t,
      const tapasco_device_alloc_flag_t flags = TAPASCO_DEVICE_ALLOC_FLAGS_NONE,
      const tapasco_copy_direction_flag_t copy_flags =
          TAPASCO_COPY_DIRECTION_BOTH) noexcept {
    return set_arg(j_id, arg_idx, t.value, flags, TAPASCO_COPY_DIRECTION_TO);
  }

  /** Sets a single pointer argument (alloc + copy). **/
  template <typename T>
  tapasco_res_t set_arg(
      tapasco_job_id_t const j_id, size_t const arg_idx, WrappedPointer<T> t,
      const tapasco_device_alloc_flag_t flags = TAPASCO_DEVICE_ALLOC_FLAGS_NONE,
      const tapasco_copy_direction_flag_t copy_flags =
          TAPASCO_COPY_DIRECTION_BOTH) noexcept {
    static_assert(is_trivially_copyable<T>::value,
                  "Types must be trivially copyable!");
    return tapasco_device_job_set_arg_transfer(devctx, j_id, arg_idx, t.sz,
                                               t.value, flags, copy_flags);
  }

  template <typename T>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, size_t arg_idx,
                         T &t) noexcept {
    return set_arg(j_id, arg_idx, t);
  }

  /** Variadic: recursively sets all given arguments. **/
  template <typename T, typename... Targs>
  tapasco_res_t set_args(tapasco_job_id_t const j_id, size_t arg_idx, T &t,
                         Targs... args) noexcept {
    tapasco_res_t r;
    if ((r = set_arg(j_id, arg_idx, t)) != TAPASCO_SUCCESS)
      return r;
    return set_args(j_id, arg_idx + 1, args...);
  }
  /* Setters for register values @} */

  /* @{ Getters for register values */
  /** Default behaviour. Copying according to flags is handled inside the
   * tapasco API be default. **/
  template <typename T>
  tapasco_res_t get_arg(tapasco_job_id_t const j_id, size_t const arg_idx,
                        T &t) noexcept {
    return TAPASCO_SUCCESS;
  }

  /** Gets a single pointer argument (copy + dealloc). **/
  template <typename T>
  tapasco_res_t get_arg(tapasco_job_id_t const j_id, size_t const arg_idx,
                        T *t) noexcept {
    if (sizeof(*t) <= 8) {
      return tapasco_device_job_get_arg(devctx, j_id, arg_idx, sizeof(*t), t);
    }
    return TAPASCO_SUCCESS;
  }

  template <typename T>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, size_t const arg_idx,
                         T &t) noexcept {
    return get_arg(j_id, arg_idx, t);
  }

  /** Variadic: recursively gets all given arguments. **/
  template <typename T, typename... Targs>
  tapasco_res_t get_args(tapasco_job_id_t const j_id, size_t const arg_idx,
                         T &t, Targs... args) noexcept {
    tapasco_res_t r;
    if ((r = get_arg(j_id, arg_idx, t)) != TAPASCO_SUCCESS)
      return r;
    return get_args(j_id, arg_idx + 1, args...);
  }
  /* Getters for register values @} */

  bool _ok{false};
  tapasco_ctx_t *ctx{nullptr};
  tapasco_devctx_t *devctx{nullptr};
};

} /* namespace tapasco */

#endif /* TAPASCO_HPP__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
