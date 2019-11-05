#ifndef HSA_TYPES_H
#define HSA_TYPES_H

#define HSA_LARGE_MODEL 1

typedef struct hsa_signal_s {
  uint64_t handle;
} hsa_signal_t;

typedef enum {
  HSA_PACKET_TYPE_VENDOR_SPECIFIC = 0,
  HSA_PACKET_TYPE_INVALID = 1,
  HSA_PACKET_TYPE_KERNEL_DISPATCH = 2,
  HSA_PACKET_TYPE_BARRIER_AND = 3,
  HSA_PACKET_TYPE_AGENT_DISPATCH = 4,
  HSA_PACKET_TYPE_BARRIER_OR = 5
} hsa_packet_type_t;

typedef enum {
  HSA_PACKET_HEADER_TYPE = 0,
  HSA_PACKET_HEADER_BARRIER = 8,
  HSA_PACKET_HEADER_SCACQUIRE_FENCE_SCOPE = 9,
  HSA_PACKET_HEADER_ACQUIRE_FENCE_SCOPE = 9,
  HSA_PACKET_HEADER_SCRELEASE_FENCE_SCOPE = 11,
  HSA_PACKET_HEADER_RELEASE_FENCE_SCOPE = 11
} hsa_packet_header_t;

typedef enum {
  HSA_PACKET_HEADER_WIDTH_TYPE = 8,
  HSA_PACKET_HEADER_WIDTH_BARRIER = 1,
  HSA_PACKET_HEADER_WIDTH_SCACQUIRE_FENCE_SCOPE = 2,
  HSA_PACKET_HEADER_WIDTH_ACQUIRE_FENCE_SCOPE = 2,
  HSA_PACKET_HEADER_WIDTH_SCRELEASE_FENCE_SCOPE = 2,
  HSA_PACKET_HEADER_WIDTH_RELEASE_FENCE_SCOPE = 2
} hsa_packet_header_width_t;

typedef enum {
  HSA_FENCE_SCOPE_NONE = 0,
  HSA_FENCE_SCOPE_AGENT = 1,
  HSA_FENCE_SCOPE_SYSTEM = 2
} hsa_fence_scope_t;

typedef enum {
  HSA_KERNEL_DISPATCH_PACKET_SETUP_DIMENSIONS = 0
} hsa_kernel_dispatch_packet_setup_t;

typedef enum {
  HSA_KERNEL_DISPATCH_PACKET_SETUP_WIDTH_DIMENSIONS = 2
} hsa_kernel_dispatch_packet_setup_width_t;

typedef struct hsa_kernel_dispatch_packet_s {
  uint16_t header;
  uint16_t setup;
  uint16_t workgroup_size_x;
  uint16_t workgroup_size_y;
  uint16_t workgroup_size_z;
  uint16_t reserved0;
  uint32_t grid_size_x;
  uint32_t grid_size_y;
  uint32_t grid_size_z;
  uint32_t private_segment_size;
  uint32_t group_segment_size;
  uint64_t kernel_object;
#ifdef HSA_LARGE_MODEL
  void *kernarg_address;
#elif defined HSA_LITTLE_ENDIAN
  void *kernarg_address;
  uint32_t reserved1;
#else
  uint32_t reserved1;
  void *kernarg_address;
#endif
  uint64_t reserved2;
  hsa_signal_t completion_signal;
} hsa_kernel_dispatch_packet_t;

typedef enum {
  CLAMP_TO_ZERO = 0x0,
  CLAMP_TO_EDGE = 0x1,
} fpga_borderhandling_t;

typedef enum {
  UINT16_GRAY_SCALE = 0x0,
  UINT8_RGB = 0x1,
} fpga_colormodel_t;

int get_colormodel_int_representation(std::string s) {
  if (s.compare("UINT16_GRAY_SCALE") == 0) {
    return UINT16_GRAY_SCALE;
  } else if (s.compare("UINT8_RGB") == 0) {
    return UINT8_RGB;
  } else {
    return -1;
  }
}

// define supported FPGA operations
typedef enum {
  SOBELX3x3 = 0x01,
  SOBELY3x3 = 0x02,
  SOBELXY3x3 = 0x03,
  SOBELX5x5 = 0x04,
  SOBELY5x5 = 0x05,
  SOBELXY5x5 = 0x06,
  GAUSS3x3 = 0x11,
  GAUSS5x5 = 0x12,
  MIN_FILTER3x3 = 0x21,
  MIN_FILTER5x5 = 0x22,
  MAX_FILTER3x3 = 0x23,
  MAX_FILTER5x5 = 0x24,
  MEDIAN_FILTER3x3 = 0x25,
  MEDIAN_FILTER5x5 = 0x26,
  CUSTOM_FILTER3x3 = 0x31,
  CUSTOM_FILTER5x5 = 0x32,
} fpga_operation_type_t;

int get_optype_int_representation(std::string s) {
  if (s.compare("SOBELX3x3") == 0) {
    return SOBELX3x3;
  } else if (s.compare("SOBELY3x3") == 0) {
    return SOBELY3x3;
  } else if (s.compare("SOBELXY3x3") == 0) {
    return SOBELXY3x3;
  } else if (s.compare("SOBELX5x5") == 0) {
    return SOBELX5x5;
  } else if (s.compare("SOBELY5x5") == 0) {
    return SOBELY5x5;
  } else if (s.compare("SOBELXY5x5") == 0) {
    return SOBELXY5x5;
  } else if (s.compare("GAUSS3x3") == 0) {
    return GAUSS3x3;
  } else if (s.compare("GAUSS5x5") == 0) {
    return GAUSS5x5;
  } else if (s.compare("MIN_FILTER3x3") == 0) {
    return MIN_FILTER3x3;
  } else if (s.compare("MIN_FILTER5x5") == 0) {
    return MIN_FILTER5x5;
  } else if (s.compare("MAX_FILTER3x3") == 0) {
    return MAX_FILTER3x3;
  } else if (s.compare("MAX_FILTER5x5") == 0) {
    return MAX_FILTER5x5;
  } else if (s.compare("MEDIAN_FILTER3x3") == 0) {
    return MEDIAN_FILTER3x3;
  } else if (s.compare("MEDIAN_FILTER5x5") == 0) {
    return MEDIAN_FILTER5x5;
  } else {
    return -1;
  }
}

uint16_t header(hsa_packet_type_t type) {
  uint16_t header = type << HSA_PACKET_HEADER_TYPE;
  header |= 0 << HSA_PACKET_HEADER_BARRIER;
  header |= HSA_FENCE_SCOPE_NONE << HSA_PACKET_HEADER_SCACQUIRE_FENCE_SCOPE;
  header |= HSA_FENCE_SCOPE_NONE << HSA_PACKET_HEADER_SCRELEASE_FENCE_SCOPE;
  return header;
}

uint16_t setup(uint16_t dims) {
  return (dims & ((1 << HSA_KERNEL_DISPATCH_PACKET_SETUP_WIDTH_DIMENSIONS) - 1))
         << HSA_KERNEL_DISPATCH_PACKET_SETUP_DIMENSIONS;
}

#endif
