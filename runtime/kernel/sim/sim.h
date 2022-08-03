#ifndef SIM_H__
#define SIM_H__

#include "tlkm_platform.h"

#define SIM_NAME "sim"
#define SIM_CLASS_NAME "sim"

#define SIM_DEF INIT_PLATFORM(0x80000000, 0x00002000 /* status */)

static const struct platform sim_def = SIM_DEF;

#ifdef __KERNEL__
#include "tlkm_class.h"
#include "sim_device.h"
#include "sim_ioctl.h"
#include "sim_irq.h"

static inline void sim_remove(struct tlkm_class *cls)
{
}

static const struct tlkm_class sim_cls = {
  .name = SIM_CLASS_NAME,
  .create = sim_device_init,
  .destroy = sim_device_exit,
  .init_subsystems = sim_device_init_subsystems,
  .exit_subsystems = sim_device_exit_subsystems,
  .probe = sim_device_probe,
  .remove = sim_remove,
  .init_interrupts = sim_irq_init,
  .exit_interrupts = sim_irq_exit,
  .pirq = sim_irq_request_platform_irq,
  .rirq = sim_irq_release_platform_irq,
  .number_of_interrupts = 132,
  .private_data = NULL,
};

#endif /* __KERNEL__ */

#endif /* SIM_H__ */
