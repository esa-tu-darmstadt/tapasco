#ifndef PCIE_H__
#define PCIE_H__

#define TLKM_PCI_NAME					"tlkm"
#define XILINX_VENDOR_ID   				0x10EE
#define XILINX_DEVICE_ID   				0x7038

int  pcie_init(void);
void pcie_deinit(void);

#endif /* PCIE_H__ */
