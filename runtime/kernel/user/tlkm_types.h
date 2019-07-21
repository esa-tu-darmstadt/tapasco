#ifndef TLKM_TYPES_H__
#define TLKM_TYPES_H__

#ifndef __KERNEL__
#include <stdint.h>
typedef uint32_t u32;
typedef int32_t s32;
typedef uint64_t u64;
typedef int64_t s64;
#else
typedef uintptr_t intptr_t;
#endif

typedef u32 dev_id_t;
typedef intptr_t dev_addr_t;

#endif /* TLKM_TYPES_H__ */
