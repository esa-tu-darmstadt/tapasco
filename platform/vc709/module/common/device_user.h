//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file device_user.h 
 * @brief Composition of everything needed for the char-device(s) for user-calls
	Functions to (un/)load this device and interrupt handlers
	these handlers will be registered as msi irqs, when the pcie_device is loaded
 * */

#ifndef __DEVICE_USER_H
#define __DEVICE_USER_H

/******************************************************************************/
/* helper functions called to (un/)load this char device */

int char_user_register(void);
void char_user_unregister(void);

/******************************************************************************/
/* interrupt handler used by user cores registered in pcie_device.c */

irqreturn_t intr_handler_user_0(int irq, void * dev_id);
irqreturn_t intr_handler_user_1(int irq, void * dev_id);
irqreturn_t intr_handler_user_2(int irq, void * dev_id);
irqreturn_t intr_handler_user_3(int irq, void * dev_id);

/******************************************************************************/

#endif // __DEVICE_USER_H
