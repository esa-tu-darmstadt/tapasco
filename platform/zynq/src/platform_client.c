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
//! @file	platform_client.c
//! @brief	Platform API implementation for Zynq platform (simulation).
//!		Interfaces with remote simulator via IPC (socket) communication
//!		to remote control the simulator.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @version	1.1
//! @copyright  Copyright 2014, 2015 J. Korinth
//!
//!		This file is part of Tapasco (TPC).
//!
//!  		Tapasco is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		Tapasco is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with Tapasco.  If not, see
//!		<http://www.gnu.org/licenses/>.
//!
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <assert.h>
#include <inttypes.h>
#include <pthread.h>

#include "platform.h"
#include "platform_api.h"
#include "platform_server.h"
#include "platform_logging.h"

/** @todo Refactor: remove global sock. **/
/** global: client socket. **/
static int sock[MAX_SOCKETS];
static int lock[MAX_SOCKETS];
static platform_irq_callback_t callback[10] = {NULL};
static int callback_cnt = 0;
static pthread_mutex_t callback_lock = PTHREAD_MUTEX_INITIALIZER;

/******************************************************************************/
/* Helpers */
#define FATAL(...) fatalerr(__func__, __VA_ARGS__)

static inline void fatalerr(char const *func, char const *fmt, ...)
{
	va_list vl;
	va_start(vl, fmt);
	fprintf(stderr, "platform-client (%s): ", __func__);
	vfprintf(stderr, fmt, vl);
	fprintf(stderr, "\nerror: %s\n", strerror(errno));
	va_end(vl);
}

/** Helper: Send bytes via socket. */
static int send_n_bytes(int conn_sock, size_t no_of_bytes, const void *data)
{
	int ret;
	do {
		ret = send(conn_sock, data, no_of_bytes, 0);
	} while (ret != no_of_bytes);
	return ret;
}

/** Helper: Receive bytes via socket. */
static int recv_n_bytes(int conn_sock, size_t no_of_bytes, void *data)
{
	int ret;
	do {
		ret = recv(conn_sock, data, no_of_bytes, 0);
		if (ret < 0)
			LOG(LPLL_INIT, "waiting for data...");
	} while (ret < 0);
	return ret;
}

/** Helper: Acknowledge reception. */
static int send_ack(int conn_sock)
{
	return send(conn_sock, &ACK, sizeof(ACK), 0) == sizeof(ACK);
}

/** Helper: Wait for acknowledgement. */
static int recv_ack(int conn_sock)
{
	unsigned char ret = 0;
	recv_n_bytes(conn_sock, 1, &ret);
	if (ret != ACK) ERR("failed to receive ACK");
	return ret == ACK;
}

/** Helper: Send remote control command to simulator. */
static int send_cmd(int conn_sock, unsigned char cmd)
{
	return send_n_bytes(conn_sock, 1, &cmd) && recv_ack(conn_sock);
}

/** Helper: lock mutex on socket. */
static inline int sock_lock(void)
{
	unsigned int sid = 0;
	while (__atomic_test_and_set(&lock[sid], __ATOMIC_SEQ_CST)) {
		/* busy waiting scheme */
		sid = (sid + 1) % MAX_SOCKETS;
	} 
	// LOG(LPLL_INIT, "socket #%d locked", sid);
	return sid;
}

/** Helper: unlock mutex on socket. */
static inline void sock_unlock(int s)
{
	LOG(LPLL_INIT, "socket #%d unlocked", s);
	__atomic_clear(&lock[s], __ATOMIC_SEQ_CST);
}

/******************************************************************************/

/** Enables the interrupt controllers. */
static platform_res_t enable_interrupts(void)
{
	int32_t const on = -1, off = 0;
	int32_t outstanding = 0;
	uint32_t intcs = 1;
	platform_read_ctl(platform_address_get_special_base(
			PLATFORM_SPECIAL_CTL_STATUS) + 0x4,
			4, &intcs, PLATFORM_CTL_FLAGS_NONE);
	assert (intcs > 0 && intcs <= ZYNQ_PLATFORM_INTC_NUM);
	LOG(LPLL_IRQ, "enabling interrupts at %d controllers", intcs);
	for (int i = 0; i < intcs; ++i) {
		platform_ctl_addr_t intc = INTC_BASE + INTC_OFFS * i;
		// disable all interrupts
		platform_write_ctl(intc + 0x8, sizeof(off), &off, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc + 0x1c, sizeof(off), &off, PLATFORM_CTL_FLAGS_NONE);
		// check & ack all outstanding IRQs
		platform_read_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
		// enable all interrupts
		platform_write_ctl(intc + 0x8, sizeof(on), &on, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc + 0x1c, sizeof(on), &on, PLATFORM_CTL_FLAGS_NONE);
		platform_read_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
	}
	return PLATFORM_SUCCESS;
}

/** Opens socket idx and attempts to connect to simulator. */
static platform_res_t open_sock_conn(unsigned int const idx)
{
	assert(idx < MAX_SOCKETS);
	if ((sock[idx] = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		ERR("could not create socket %d", idx);
		return PLATFORM_FAILURE;
	}
	char socket_path[1024];
	snprintf(socket_path, 1023, "%s_%03u", getenv("LIBPLATFORM_DPI_SOCKET") ?
		getenv("LIBPLATFORM_DPI_SOCKET") : "LIBPLATFORM_DPI", idx);

	struct sockaddr_un remote;
	remote.sun_family = AF_UNIX;
	strcpy(remote.sun_path, socket_path);
	int len = strlen(remote.sun_path) + sizeof(remote.sun_family);

	int tries = 0, connected = 0;
	for (tries = 0; tries < 10 && ! connected; tries++) {
		// LOG(LPLL_INIT, "attempting to connect to simulator");
		connected = connect(sock[idx], (struct sockaddr *)&remote, len) == 0;
		if (! connected) {
			LOG(LPLL_INIT, "connection to socket #%u failed: %s", idx, strerror(errno));
			sleep(1);
		}
	}

	if (! connected) {
		ERR("no connection to simulator after 10 attempts");
		return PLATFORM_FAILURE;
	}

	LOG(LPLL_INIT, "connected to simulator with socket %u", idx);
	return sock[idx] ? PLATFORM_SUCCESS : PERR_NO_CONNECTION;
}

static void *run_open_socket(void *p)
{
	const size_t idx = (size_t)p;
	return (void *)open_sock_conn(idx);
}

platform_res_t _platform_init(const char *const version)
{
	platform_logging_init();
	LOG(LPLL_INIT, "Platform API Version: %s", platform_version());
	if (platform_check_version(version) != PLATFORM_SUCCESS) {
		ERR("Platform API version mismatch: found %s, expected %s",
				platform_version(), version);
		return PERR_VERSION_MISMATCH;
	}

	long int socket_cnt = 48;
	void *res[48];
	pthread_t t[48];

	LOG(LPLL_INIT, "number of sockets: %ld", socket_cnt);
	assert(socket_cnt > 0 && socket_cnt <= MAX_SOCKETS);
	for (int i = 0; i < MAX_SOCKETS; ++i)
		__atomic_test_and_set(&lock[i], __ATOMIC_SEQ_CST);
	memset(sock, 0, sizeof(sock));

	for (long i = socket_cnt-1; i >= 0; --i) {
		int pr = pthread_create(&t[i], NULL, run_open_socket, (void *)i);
		if (pr != 0)
			ERR("could not create thread: %d\n", pr);
	}
	for (long i = socket_cnt-1; i >= 0; --i)
		pthread_join(t[i], &res[i]);

	while (socket_cnt) {
		--socket_cnt;
		// platform_res_t r = open_sock_conn(socket_cnt);
		if ((platform_res_t)res[socket_cnt] != PLATFORM_SUCCESS)
			return (platform_res_t)res[socket_cnt];
		else
			__atomic_clear(&lock[socket_cnt], __ATOMIC_SEQ_CST);
	}
	return enable_interrupts();
}

void platform_deinit(void)
{
	platform_stop(0);
	for (int s = 0; s < MAX_SOCKETS; ++s)
		close(sock[s]);
	LOG(LPLL_INIT, "client deinitialized");
	platform_logging_exit();
}

/******************************************************************************/

platform_res_t platform_alloc(size_t const len, platform_mem_addr_t *addr,
		platform_alloc_flags_t const flags)
{
	static uint64_t next_addr = 0x01700000UL;
	LOG(LPLL_MM, "len = %zu bytes", len);
	*addr = __atomic_fetch_add(&next_addr, len, __ATOMIC_SEQ_CST);
	return PLATFORM_SUCCESS;
}

platform_res_t platform_dealloc(platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags)
{
	LOG(LPLL_MM, "addr = %u", addr);
	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_mem(platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void *data,
		platform_mem_flags_t const flags)
{
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_READ_MEM) &&
		send_n_bytes(sock[s_id], sizeof(start_addr), &start_addr) &&
		send_n_bytes(sock[s_id], sizeof(no_of_bytes), &no_of_bytes) &&
		recv_ack(sock[s_id]);
	LOG(LPLL_MEM, "arg ack received, waiting for data");

	unsigned char *ptr = data;
	int bc = no_of_bytes, sz = 0;
	do {
		sz = recv_n_bytes(sock[s_id], bc, ptr);
		ptr += sz;
		bc -= sz;
		// DBG("received %d bytes", sz);
	} while (bc > 0 && sz > 0);

	ret = ret && bc == 0;
	send_ack(sock[s_id]);

	if (! ret)
		ERR("platform_read_mem failed");
	else
		LOG(LPLL_MEM, "read %zd bytes from 0x%08lx", no_of_bytes,
				(unsigned long)start_addr);

	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_write_mem(platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void const*data,
		platform_mem_flags_t const flags)
{
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)start_addr, no_of_bytes);
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_WRITE_MEM) &&
		send_n_bytes(sock[s_id], sizeof(start_addr), &start_addr) &&
		send_n_bytes(sock[s_id], sizeof(no_of_bytes), &no_of_bytes) &&
		recv_ack(sock[s_id]);
	LOG(LPLL_MEM, "arg ack received, sending data");
	ret = ret &&
		send_n_bytes(sock[s_id], no_of_bytes, data) &&
		recv_ack(sock[s_id]);

	if (! ret)
		ERR("platform_write_mem failed");
	else
		LOG(LPLL_MEM, "wrote %zu bytes to 0x%x", no_of_bytes, start_addr);

	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_read_ctl(platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes, void *data,
		platform_ctl_flags_t const flags)
{
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_READ_CTL) &&
		send_n_bytes(sock[s_id], sizeof(start_addr), &start_addr) &&
		send_n_bytes(sock[s_id], sizeof(no_of_bytes), &no_of_bytes) &&
		recv_ack(sock[s_id]);
	LOG(LPLL_CTL, "arg ack received, waiting for data");

	unsigned char *ptr = data;
	int bc = no_of_bytes, sz = 0;
	do {
		sz = recv_n_bytes(sock[s_id], bc, ptr);
		ptr += sz;
		bc -= sz;
		// DBG("received %d bytes", sz);
	} while (bc > 0 && sz > 0);

	ret = ret && bc == 0;
	send_ack(sock[s_id]);

	if (! ret)
		ERR("platform_read_ctl failed");
	else
		LOG(LPLL_CTL, "read %zu bytes from 0x%08lx", no_of_bytes,
				(unsigned long)start_addr);
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_write_ctl(platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes, void const*data,
		platform_ctl_flags_t const flags)
{
	LOG(LPLL_CTL, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)start_addr, no_of_bytes);
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_WRITE_CTL) &&
		send_n_bytes(sock[s_id], sizeof(start_addr), &start_addr) &&
		send_n_bytes(sock[s_id], sizeof(no_of_bytes), &no_of_bytes) &&
		recv_ack(sock[s_id]);
	LOG(LPLL_CTL, "arg ack received, sending data");
	ret = ret &&
		send_n_bytes(sock[s_id], no_of_bytes, data) &&
		recv_ack(sock[s_id]);

	if (! ret)
		ERR("platform_write_ctl failed");
	else
		LOG(LPLL_CTL, "wrote %zu bytes to 0x%08lx", no_of_bytes,
				(unsigned long)start_addr);
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_write_ctl_and_wait(platform_ctl_addr_t const w_addr,
		size_t const w_no_of_bytes, void const*w_data,
		uint32_t const event, platform_ctl_flags_t const flags)
{
	LOG(LPLL_CTL, "w_addr = 0x%08x, w_no_of_bytes = %zu, event = %u",
			w_addr, w_no_of_bytes, event);
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_WRITE_CTL_AND_WAIT) &&
		send_n_bytes(sock[s_id], sizeof(w_addr), &w_addr) &&
		send_n_bytes(sock[s_id], sizeof(w_no_of_bytes), &w_no_of_bytes) &&
		send_n_bytes(sock[s_id], sizeof(event), &event) &&
		recv_ack(sock[s_id]);
	LOG(LPLL_CTL, "ack received, sending %zu bytes ...", w_no_of_bytes);
	ret = ret && send_n_bytes(sock[s_id], w_no_of_bytes, w_data) && recv_ack(sock[s_id]);
	LOG(LPLL_CTL, "done");
	sock_unlock(s_id);
	while (pthread_mutex_trylock(&callback_lock))
		usleep(10);
	for (int cbi = 0; cbi < callback_cnt; ++cbi)
		(*callback[cbi])(event);
	pthread_mutex_unlock(&callback_lock);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_wait_for_event(uint32_t const event)
{
	LOG(LPLL_IRQ, "event = %d", event);
	int const s_id = sock_lock();
	int irq_status = 0;
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_WAIT_FOR_EVENT) && recv_ack(sock[s_id]);
	LOG(LPLL_IRQ, "ack received, waiting");
	ret = ret &&
		recv_n_bytes(sock[s_id], sizeof(irq_status), &irq_status) &&
		send_ack(sock[s_id]);
	LOG(LPLL_IRQ, "received irq status = 0x%08x", irq_status);
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_register_irq_callback(platform_irq_callback_t cb)
{
	platform_res_t r = PLATFORM_FAILURE;
	while (pthread_mutex_trylock(&callback_lock))
		usleep(10);
	if (callback_cnt < 10) {
		callback[callback_cnt] = cb;
		++callback_cnt;
		r = PLATFORM_SUCCESS;
	}
	pthread_mutex_unlock(&callback_lock);
	return r;
}

/********************************************************************************/

platform_res_t platform_stop(const int result)
{
	LOG(LPLL_INIT, "sending stop kernel cmd: result = %d", result);
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_STOP)
			&& send_n_bytes(sock[s_id], sizeof(result), &result)
			&& recv_ack(sock[s_id]);
	if (ret)
		LOG(LPLL_INIT, "stop command sent");
	else
		ERR("stop command failed");
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_get_time(int64_t *time)
{
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_GET_TIME) &&
		recv_n_bytes(sock[s_id], sizeof(*time), time) &&
		send_ack(sock[s_id]);
	if (ret)
		LOG(LPLL_INIT, "get time successful: %" PRId64, *time);
	else
		ERR("get time failed");
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

platform_res_t platform_wait_cycles(const int cycles)
{
	int const s_id = sock_lock();
	int ret = send_cmd(sock[s_id], PLATFORM_CMD_WAIT_CYCLES) &&
		send_n_bytes(sock[s_id], sizeof(cycles), &cycles) &&
		recv_ack(sock[s_id]);
	if (ret)
		LOG(LPLL_INIT, "waited %u cycles", cycles);
	else
		ERR("wait %u cycles failed", cycles);
	sock_unlock(s_id);
	return ret ? PLATFORM_SUCCESS : PLATFORM_FAILURE;
}

