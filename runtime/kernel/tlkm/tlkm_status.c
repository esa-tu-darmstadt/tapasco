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
#include "tlkm_logging.h"
#include "tlkm_status.h"
#include "tlkm_device.h"
#include <pb_decode.h>

bool parse_string(pb_istream_t *stream, const pb_field_t *field, void **arg);
bool add_component(pb_istream_t *stream, const pb_field_t *field, void **arg);

bool parse_string(pb_istream_t *stream, const pb_field_t *field, void **arg)
{
	size_t bytes_to_read =
		31 > stream->bytes_left ? stream->bytes_left : 31;
	memset(*arg, 0, 32);
	pb_read(stream, *arg, bytes_to_read);
	return true;
}

typedef struct {
	struct tlkm_device *dev;
	int cntr;
} add_component_helper_t;

bool add_component(pb_istream_t *stream, const pb_field_t *field, void **arg)
{
	tapasco_status_Platform plat = tapasco_status_Platform_init_zero;
	add_component_helper_t *help = *arg;
	bool ret = false;
	plat.name = (pb_callback_t){
		{
			.decode = &parse_string,
		},
		.arg = &help->dev->components[help->cntr].name,
	};

	ret = pb_decode(stream, tapasco_status_Platform_fields, &plat);
	help->dev->components[help->cntr].offset = plat.offset;
	help->dev->components[help->cntr].size = plat.size;
	DEVLOG(help->dev->dev_id, TLKM_LF_STATUS, "Detected component %s @ %lx with size %llx",
	       help->dev->components[help->cntr].name,
	       help->dev->components[help->cntr].offset,
	       help->dev->components[help->cntr].size);
	++help->cntr;

	return ret;
}

int tlkm_status_init(tlkm_status *sta, struct tlkm_device *dev,
		     void __iomem *status, size_t status_size)
{
	int parse_status;
	pb_istream_t stream;
	int i;
	add_component_helper_t add_component_helper = { .dev = dev, .cntr = 0 };
	BUG_ON(!dev);
	BUG_ON(!sta);
	DEVLOG(dev->dev_id, TLKM_LF_STATUS,
	       "reading status core of size %zu from %p ...", status_size,
	       status);
	for (i = 0; i < TLKM_COMPONENT_MAX; i += 1) {
		memset(dev->components[i].name, 0, TLKM_COMPONENTS_NAME_MAX);
		dev->components[i].offset = -1;
	}

	*sta = (tapasco_status_Status)tapasco_status_Status_init_zero;
	sta->platform = (pb_callback_t){ {
						 .decode = &add_component,
					 },
					 .arg = &add_component_helper };
	stream = pb_istream_from_buffer(status, status_size);
	parse_status =
		pb_decode_delimited(&stream, tapasco_status_Status_fields, sta);

	if (!parse_status) {
		DEVERR(dev->dev_id, "Error reading status core: %s",
		       PB_GET_ERROR(&stream));
		return -ENOSPC;
	}

	DEVLOG(dev->dev_id, TLKM_LF_STATUS, "Successfully read status core");

	return 0;
}

void tlkm_status_exit(tlkm_status *sta, struct tlkm_device *dev)
{
	*sta = (tapasco_status_Status)tapasco_status_Status_init_zero;
	DEVLOG(dev->dev_id, TLKM_LF_STATUS, "destroyed tlkm_status");
}

dev_addr_t tlkm_status_get_component_base(struct tlkm_device *dev,
					  const char *c)
{
	int i;
	for (i = 0; i < TLKM_COMPONENT_MAX; ++i) {
		if (strncmp(c, dev->components[i].name,
			    TLKM_COMPONENTS_NAME_MAX) == 0) {
			return dev->components[i].offset;
		}
	}
	return -1;
}

u64 tlkm_status_get_component_size(struct tlkm_device *dev, const char *c)
{
	int i;
	for (i = 0; i < TLKM_COMPONENT_MAX; ++i) {
		if (strncmp(c, dev->components[i].name,
			    TLKM_COMPONENTS_NAME_MAX) == 0) {
			return dev->components[i].size;
		}
	}
	return -1;
}