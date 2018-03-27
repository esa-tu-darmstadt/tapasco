#ifndef TLKM_BUS_H__
#define TLKM_BUS_H__

struct tlkm_bus;

int tlkm_enumerate(void);

void add_device(struct tlkm_device *pdev);
void del_device(struct tlkm_device *pdev);

#endif /* TLKM_BUS_H__ */
