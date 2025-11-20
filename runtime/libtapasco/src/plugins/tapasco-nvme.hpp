/*
 * Copyright (c) 2014-2025 Embedded Systems and Applications, TU Darmstadt.
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

#ifndef TAPASCO_NVME_HPP__
#define TAPASCO_NVME_HPP__

#include <tapasco.hpp>

using namespace tapasco;

/**
 * C++ Wrapper class for NVMe runtime plugin.
 */
class TapascoNvmePlugin {
public:
  /**
   * Retrieve instance of NVMe plugin C++ wrapper class.
   *
   * @param d TaPaSCo device corresponding to the plugin
   * @return NVMe plugin wrapper object
   */
  static TapascoNvmePlugin get_instance(Device *d) {
    auto plugin_ptr = tapasco_get_nvme_plugin(d);
    if (plugin_ptr == 0) {
      handle_error();
    }
    return TapascoNvmePlugin(plugin_ptr);
  }

  /**
   * Check whether NVMe plugin is available on current device
   *
   * @return true if plugin is available
   */
  bool is_available() {
    bool available = false;
    if (tapasco_nvme_is_available(this->plugin, &available)) {
      handle_error();
    }
    return available;
  }

  /**
   * Check whether NVMe Streamer IP and plugin is enabled on current device
   *
   * @return ture if NVMe Streamer IP is enabled
   */
  bool is_enabled() {
    bool enabled = false;
    if (tapasco_nvme_is_enabled(this->plugin, &enabled)) {
      handle_error();
    }
    return enabled;
  }

  /**
   * Set PCIe address of the NVMe controller in NVMe Streamer IP
   *
   * @param addr PCIe address of NVMe controller
   */
  void set_nvme_pcie_addr(uint64_t addr) {
    if (tapasco_nvme_set_nvme_pcie_addr(this->plugin, addr)) {
      handle_error();
    }
  }

  /**
   * Set namespace ID to be used for transfers in NVMe Streamer IP
   *
   * @param id Namespace ID to be used
   */
  void set_namespace_id(uint64_t id) {
    if (tapasco_nvme_set_namespace_id(this->plugin, id)) {
      handle_error();
    }
  }

  /**
   * Returns tuple with PCIe addresses of submission and completion queues
   * in the NVMe Streamer IP
   *
   * @return Tuple containing PCIe addresses of Submission (first element)
   * and Completion Queue (second element)
   */
  std::tuple<uint64_t, uint64_t> get_queue_base_addr() {
    uint64_t sq_addr = 0, cq_addr = 0;
    if (tapasco_nvme_get_queue_base_addr(this->plugin, &sq_addr, &cq_addr)) {
      handle_error();
    }
    return {sq_addr, cq_addr};
  }

  /**
   * Enable plugin and NVMe Streamer IP
   */
  void enable() {
    if (tapasco_nvme_enable(this->plugin)) {
      handle_error();
    }
  }

  /**
   * Disable plugin and NVMe Streamer IP
   */
  void disable() {
    if (tapasco_nvme_disable(this->plugin)) {
      handle_error();
    }
  }

private:
  TapascoNvmePlugin(NvmePlugin *p) : plugin(p) {}
  NvmePlugin *plugin;
};

#endif /* TAPASCO_NVME_HPP__ */