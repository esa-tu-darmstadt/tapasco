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
#ifndef PLATFORM_COMPONENTS_H__
#define PLATFORM_COMPONENTS_H__

/**
 * Platform component identifiers.
 * NOTE: This will be parsed by a simple regex in Tcl, which uses the order of
 * appearance to determine the value of the constant; make sure not to change
 * the values by assigning explicitly, or start at something other than 0.
 **/
typedef enum {
  /** TaPaSCo Status Core: bitstream information. **/
  PLATFORM_COMPONENT_STATUS = 0,
  /** ATS/PRI checker. **/
  PLATFORM_COMPONENT_ATSPRI,
  /** Interrupt controller #0. **/
  PLATFORM_COMPONENT_INTC0,
  /** Interrupt controller #1. **/
  PLATFORM_COMPONENT_INTC1,
  /** Interrupt controller #2. **/
  PLATFORM_COMPONENT_INTC2,
  /** Interrupt controller #3. **/
  PLATFORM_COMPONENT_INTC3,
  /** MSI-X Interrupt controller #0. **/
  PLATFORM_COMPONENT_MSIX0,
  /** MSI-X Interrupt controller #1. **/
  PLATFORM_COMPONENT_MSIX1,
  /** MSI-X Interrupt controller #2. **/
  PLATFORM_COMPONENT_MSIX2,
  /** MSI-X Interrupt controller #3. **/
  PLATFORM_COMPONENT_MSIX3,
  /** DMA engine #0. **/
  PLATFORM_COMPONENT_DMA0,
  /** DMA engine #1. **/
  PLATFORM_COMPONENT_DMA1,
  /** DMA engine #2. **/
  PLATFORM_COMPONENT_DMA2,
  /** DMA engine #3. **/
  PLATFORM_COMPONENT_DMA3,
  /** AXI GPIO controller for memory status (on EC2) **/
  PLATFORM_COMPONENT_MEM_GPIO,
  /** Dummy component indicating the AWS EC2 platform **/
  PLATFORM_COMPONENT_AWS_EC2,
  /** ECC Configuration + Status. **/
  PLATFORM_COMPONENT_ECC,
} platform_component_t;

#endif /* PLATFORM_COMPONENTS_H__ */
