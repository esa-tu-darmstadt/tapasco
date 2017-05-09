//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
#ifndef __PLATFORM_H__
#define __PLATFORM_H__

#define COMMANDS	\
	_X(PLATFORM_CMD_CONNECT             , 0x42 , 0 , parse_platform_connect) \
	_X(PLATFORM_CMD_STOP                , 0xAF , 0 , parse_platform_finish) \
	_X(PLATFORM_CMD_GET_TIME            , 0x06 , 0 , parse_platform_get_time) \
	_X(PLATFORM_CMD_WAIT_CYCLES         , 0x07 , 0 , parse_platform_wait_cycles) \
	_X(PLATFORM_CMD_READ_MEM            , 0x08 , 1 , parse_platform_read_mem) \
	_X(PLATFORM_CMD_WRITE_MEM           , 0x09 , 1 , parse_platform_write_mem) \
	_X(PLATFORM_CMD_READ_CTL            , 0x0A , 1 , parse_platform_read_ctl) \
	_X(PLATFORM_CMD_WRITE_CTL           , 0x0B , 1 , parse_platform_write_ctl) \
	_X(PLATFORM_CMD_WRITE_CTL_AND_WAIT  , 0x0C , 1 , parse_platform_write_ctl_and_wait) \
	_X(PLATFORM_CMD_WAIT_FOR_EVENT      , 0x0D , 1 , parse_platform_wait_for_event)

static const unsigned char ACK = (unsigned char)0x77;
#ifdef _X
  #undef _X
#endif
#define _X(name, val, len, parser) static const unsigned char name = (unsigned char)val;
COMMANDS
#undef _X

#endif /* __PLATFORM_H__ */
