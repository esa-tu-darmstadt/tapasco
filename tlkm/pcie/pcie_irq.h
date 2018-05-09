#ifndef PCIE_IRQ_H__
#define PCIE_IRQ_H__

#include "tlkm_device.h"

#ifdef _INTR
	#undef _INTR
#endif

#define TLKM_PCIE_SLOT_INTERRUPTS \
	_INTR(0)	\
	_INTR(1)	\
	_INTR(2)	\
	_INTR(3)	\
	_INTR(4)	\
	_INTR(5)	\
	_INTR(6)	\
	_INTR(7)	\
	_INTR(8)	\
	_INTR(9)	\
	_INTR(10)	\
	_INTR(11)	\
	_INTR(12)	\
	_INTR(13)	\
	_INTR(14)	\
	_INTR(15)	\
	_INTR(16)	\
	_INTR(17)	\
	_INTR(18)	\
	_INTR(19)	\
	_INTR(20)	\
	_INTR(21)	\
	_INTR(22)	\
	_INTR(23)	\
	_INTR(24)	\
	_INTR(25)	\
	_INTR(26)	\
	_INTR(27)	\
	_INTR(28)	\
	_INTR(29)	\
	_INTR(30)	\
	_INTR(31)	\
	_INTR(32)	\
	_INTR(33)	\
	_INTR(34)	\
	_INTR(35)	\
	_INTR(36)	\
	_INTR(37)	\
	_INTR(38)	\
	_INTR(39)	\
	_INTR(40)	\
	_INTR(41)	\
	_INTR(42)	\
	_INTR(43)	\
	_INTR(44)	\
	_INTR(45)	\
	_INTR(46)	\
	_INTR(47)	\
	_INTR(48)	\
	_INTR(49)	\
	_INTR(50)	\
	_INTR(51)	\
	_INTR(52)	\
	_INTR(53)	\
	_INTR(54)	\
	_INTR(55)	\
	_INTR(56)	\
	_INTR(57)	\
	_INTR(58)	\
	_INTR(59)	\
	_INTR(60)	\
	_INTR(61)	\
	_INTR(62)	\
	_INTR(63)	\
	_INTR(64)	\
	_INTR(65)	\
	_INTR(66)	\
	_INTR(67)	\
	_INTR(68)	\
	_INTR(69)	\
	_INTR(70)	\
	_INTR(71)	\
	_INTR(72)	\
	_INTR(73)	\
	_INTR(74)	\
	_INTR(75)	\
	_INTR(76)	\
	_INTR(77)	\
	_INTR(78)	\
	_INTR(79)	\
	_INTR(80)	\
	_INTR(81)	\
	_INTR(82)	\
	_INTR(83)	\
	_INTR(84)	\
	_INTR(85)	\
	_INTR(86)	\
	_INTR(87)	\
	_INTR(88)	\
	_INTR(89)	\
	_INTR(90)	\
	_INTR(91)	\
	_INTR(92)	\
	_INTR(93)	\
	_INTR(94)	\
	_INTR(95)	\
	_INTR(96)	\
	_INTR(97)	\
	_INTR(98)	\
	_INTR(99)	\
	_INTR(100)	\
	_INTR(101)	\
	_INTR(102)	\
	_INTR(103)	\
	_INTR(104)	\
	_INTR(105)	\
	_INTR(106)	\
	_INTR(107)	\
	_INTR(108)	\
	_INTR(109)	\
	_INTR(110)	\
	_INTR(111)	\
	_INTR(112)	\
	_INTR(113)	\
	_INTR(114)	\
	_INTR(115)	\
	_INTR(116)	\
	_INTR(117)	\
	_INTR(118)	\
	_INTR(119)	\
	_INTR(120)	\
	_INTR(121)	\
	_INTR(122)	\
	_INTR(123)	\
	_INTR(124)	\
	_INTR(125)	\
	_INTR(126)	\
	_INTR(127)

int  pcie_irqs_init(struct tlkm_device *dev);
void pcie_irqs_exit(struct tlkm_device *dev);
int  pcie_irqs_request_platform_irq(struct tlkm_device *dev, int irq_no, irq_handler_t, void *data);
void pcie_irqs_release_platform_irq(struct tlkm_device *dev, int irq_no);

#define _INTR(nr) \
irqreturn_t tlkm_pcie_slot_irq_ ## nr(int irq, void *dev_id); \
void tlkm_pcie_slot_irq_work_ ## nr(struct work_struct *work);
TLKM_PCIE_SLOT_INTERRUPTS
#undef _INTR

#endif /* PCIE_IRQ_H__ */
