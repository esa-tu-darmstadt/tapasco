#ifndef TLKM_ACCESS_H__
#define TLKM_ACCESS_H__

typedef enum {
	TLKM_ACCESS_EXCLUSIVE 				= 0,
	TLKM_ACCESS_MONITOR,
	TLKM_ACCESS_SHARED,
	TLKM_ACCESS_TYPES, /* length and sentinel */
} tlkm_access_t;

#endif /* TLKM_ACCESS_H__ */
