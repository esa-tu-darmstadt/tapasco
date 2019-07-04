//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (PLATFORM).
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
#include <assert.h>
#include <pb_decode.h>
#include <platform.h>
#include <platform_addr_map.h>
#include <platform_caps.h>
#include <platform_devctx.h>
#include <platform_info.h>
#include <platform_logging.h>
#include <status_core.pb.h>
#include <string.h>

extern const char *platform_component_t_str[];

static platform_info_t _info[PLATFORM_MAX_DEVS];

typedef struct parser_helper {
  platform_info_t *info;
  platform_dev_id_t dev_id;
  int counter;
} parser_helper_t;

uint32_t build_version(uint16_t major, uint16_t minor) {
  return (uint32_t)major << 16 | minor;
}

bool parse_string(pb_istream_t *stream, const pb_field_t *field, void **arg) {
  size_t bytes_to_read = 31 > stream->bytes_left ? stream->bytes_left : 31;
  memset(*arg, 0, 32);
  pb_read(stream, *arg, bytes_to_read);
  return true;
}

bool platform_helper(pb_istream_t *stream, const pb_field_t *field,
                     void **arg) {
  tapasco_status_Platform platform = tapasco_status_Platform_init_zero;
  parser_helper_t *helper = (parser_helper_t *)*arg;
  platform_info_t *info = helper->info;
  bool ret = false;

  char name[32];
  platform.name = (pb_callback_t){{
                                      .decode = &parse_string,
                                  },
                                  .arg = &name};

  ret = pb_decode(stream, tapasco_status_Platform_fields, &platform);

  DEVLOG(helper->dev_id, LPLL_STATUS, "Platform Component %s @ 0x%x S%dB.",
         name, platform.offset, platform.size);

  int i = 0;
  while (platform_component_t_str[i] != 0) {
    if (strncmp(platform_component_t_str[i], name, 32) == 0) {
      DEVLOG(helper->dev_id, LPLL_STATUS,
             "Found matching static platform entry.");
      info->base.platform[i] = platform.offset;
      break;
    }
    ++i;
  }

  return ret;
};

bool kernel_helper(pb_istream_t *stream, const pb_field_t *field, void **arg) {
  tapasco_status_PE pe = tapasco_status_PE_init_zero;
  parser_helper_t *helper = (parser_helper_t *)*arg;
  platform_info_t *info = helper->info;
  bool ret = false;

  ret = pb_decode(stream, tapasco_status_PE_fields, &pe);

  DEVLOG(helper->dev_id, LPLL_STATUS, "PE @ %d %x, Type %d, Local Memory %d.",
         helper->counter, pe.offset, pe.id, pe.local_memory);

  info->base.arch[helper->counter] = pe.offset;
  info->composition.kernel[helper->counter] = pe.id;

  if (pe.local_memory.size) {
    ++helper->counter;
    info->base.arch[helper->counter] = pe.offset;
    info->composition.kernel[helper->counter] = 0;
    info->base.arch[helper->counter] = pe.local_memory.base;
    info->composition.memory[helper->counter] = pe.local_memory.size;
  }

  ++helper->counter;

  return ret;
};

bool version_helper(pb_istream_t *stream, const pb_field_t *field, void **arg) {
  tapasco_status_Version version = tapasco_status_Version_init_zero;
  parser_helper_t *helper = (parser_helper_t *)*arg;
  platform_info_t *info = helper->info;
  bool ret = false;
  char name[32];
  version.software = (pb_callback_t){{
                                         .decode = &parse_string,
                                     },
                                     .arg = &name};

  ret = pb_decode(stream, tapasco_status_Version_fields, &version);
  if (strncmp(name, "Vivado", 32) == 0) {
    info->version.vivado = build_version(version.year, version.release);
  } else if (strncmp(name, "TaPaSCo", 32) == 0) {
    info->version.tapasco = build_version(version.year, version.release);
  } else {
    DEVLOG(helper->dev_id, LPLL_STATUS, "Unknown program version for %s.",
           name);
  }
  return ret;
};

bool clock_helper(pb_istream_t *stream, const pb_field_t *field, void **arg) {
  tapasco_status_Clock clock = tapasco_status_Clock_init_zero;
  parser_helper_t *helper = (parser_helper_t *)*arg;
  platform_info_t *info = helper->info;
  bool ret = false;
  char name[32];
  clock.name = (pb_callback_t){{
                                   .decode = &parse_string,
                               },
                               .arg = &name};

  ret = pb_decode(stream, tapasco_status_Clock_fields, &clock);
  if (strncmp(name, "Host", 32) == 0) {
    info->clock.host = clock.frequency_mhz;
  } else if (strncmp(name, "Design", 32) == 0) {
    info->clock.design = clock.frequency_mhz;
  } else if (strncmp(name, "Memory", 32) == 0) {
    info->clock.memory = clock.frequency_mhz;
  } else {
    DEVLOG(helper->dev_id, LPLL_STATUS,
           "Unknown clock %s with frequency %dMHz.", name, clock.frequency_mhz);
  }
  return ret;
};

static platform_res_t read_info_from_status_core(platform_devctx_t const *p,
                                                 platform_info_t *info) {
  platform_dev_id_t dev_id = p->dev_id;
  volatile void *status = device_regspace_status_ptr(p);
  size_t status_size = device_regspace_status_size(p);

  int parse_status;
  pb_istream_t stream;
  tapasco_status_Status status_core = tapasco_status_Status_init_zero;

  parser_helper_t helper = {.info = info, .dev_id = dev_id};

  parser_helper_t helper_with_cntr = {
      .info = info, .dev_id = dev_id, .counter = 0};

  status_core.clocks = (pb_callback_t){{
                                           .decode = &clock_helper,
                                       },
                                       .arg = &helper};

  status_core.versions = (pb_callback_t){{
                                             .decode = &version_helper,
                                         },
                                         .arg = &helper};

  status_core.pe = (pb_callback_t){{
                                       .decode = &kernel_helper,
                                   },
                                   .arg = &helper_with_cntr};

  status_core.platform = (pb_callback_t){{
                                             .decode = &platform_helper,
                                         },
                                         .arg = &helper_with_cntr};

  for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
    info->base.platform[s] = -1;
  }

  stream = pb_istream_from_buffer((void *)status, status_size);
  parse_status =
      pb_decode_delimited(&stream, tapasco_status_Status_fields, &status_core);

  if (!parse_status) {
    DEVERR(dev_id, "Could not read status core: %s", PB_GET_ERROR(&stream));
    return PERR_TLKM_ERROR;
  }

  info->magic_id = 0xe5ae1337;
  info->num_intc = 1;
  info->caps0 = PLATFORM_CAP0_PE_LOCAL_MEM | PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP;
  info->compose_ts = status_core.timestamp;

  for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
    if (info->composition.kernel[s] != 0 || info->composition.memory[s] != 0) {
      info->base.arch[s] += device_regspace_arch_base(p);
    }
  }

  for (platform_slot_id_t s = 0; s < PLATFORM_NUM_SLOTS; ++s) {
    if (info->base.platform[s] != -1) {
      info->base.platform[s] += device_regspace_platform_base(p);
    } else {
      info->base.platform[s] = 0;
    }
  }

  return PLATFORM_SUCCESS;
}

inline void log_device_info(platform_dev_id_t const dev_id,
                            platform_info_t const *info) {}

platform_res_t platform_info(platform_devctx_t const *ctx,
                             platform_info_t *info) {
  platform_res_t r = PLATFORM_SUCCESS;
  platform_dev_id_t dev_id = ctx->dev_id;
  assert(ctx);
  assert(info);
  assert(dev_id < PLATFORM_MAX_DEVS);
  if (!_info[dev_id].magic_id) {
    DEVLOG(dev_id, LPLL_STATUS, "reading device info ...");
    r = read_info_from_status_core(ctx, &_info[dev_id]);
    if (r == PLATFORM_SUCCESS) {
      DEVLOG(dev_id, LPLL_STATUS, "read device info successfully");
      log_device_info(dev_id, &_info[dev_id]);
    }
  }
  if (r == PLATFORM_SUCCESS) {
    memcpy(info, &_info[dev_id], sizeof(*info));
  }
  return r;
}
