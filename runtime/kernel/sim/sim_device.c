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
#include <linux/of.h>
#include <linux/fs.h>
#include <linux/io.h>
#include "tlkm_logging.h"
#include "tlkm_types.h"
#include "tlkm_bus.h"
#include "sim.h"
#include "sim_device.h"

static struct sim_device _sim_dev; // there is at most one Zynq

int sim_device_init(struct tlkm_device *inst, void *data)
{
#ifndef NDEBUG
	if (!inst) {
		ERR("called with NULL device instance");
		return -EACCES;
	}
#endif /* NDEBUG */
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "initializing sim device");
	inst->private_data = &_sim_dev;
	_sim_dev.parent = inst;

	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "sim successfully initialized");
	return 0;
}

void sim_device_exit(struct tlkm_device *inst)
{
#ifndef NDEBUG
	if (!inst) {
		ERR("called with NULL device instance");
		return;
	}
#endif /* NDEBUG */
	inst->private_data = NULL;
	DEVLOG(_sim_dev.parent->dev_id, TLKM_LF_DEVICE, "sim device exited");
}

int sim_device_init_subsystems(struct tlkm_device *dev, void *data)
{
	return 0;
}

void sim_device_exit_subsystems(struct tlkm_device *dev)
{
	DEVLOG(dev->dev_id, TLKM_LF_DEVICE, "exited subsystems");
}

int sim_device_probe(struct tlkm_class *cls)
{
	struct tlkm_device *inst;
  inst = tlkm_bus_new_device(cls, 0, 0, NULL);
	return 0;
}
