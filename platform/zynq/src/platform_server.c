//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
//! @file	platform_server.c
//! @brief	Platform API IPC (socket) server. Implemented in .so library
//!		called by simulator, opens IPC socket to communicate with
//!		clients. Enables remote control of the simulator. Basically
//!		only parses the commands and calls the appropriate SystemVerilog
//!		DPI tasks.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @version	1.1
//! @copyright  Copyright 2014, 2015 J. Korinth
//!
//!		This file is part of ThreadPoolComposer (TPC).
//!
//!  		ThreadPoolComposer is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		ThreadPoolComposer is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with ThreadPoolComposer.  If not, see
//!		<http://www.gnu.org/licenses/>.
//!
#include "platform_dpi.h"
#include "platform.h"
#include <svdpi.h>

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <unistd.h>
#include <assert.h>
#include <pthread.h>

#include "platform_logging.h"
#include "platform_server.h"

/** @todo Refactor: Remove globals master_sock and conn_sock. **/

static int master_sock[MAX_SOCKETS];
static int conn_sock[MAX_SOCKETS] = { -1 };
static pthread_mutex_t conn_sock_lock[MAX_SOCKETS];

/******************************************************************************/
/* Helpers */
#define FATAL(...) fatalerr(__func__, __VA_ARGS__)

/** Report fatal error and exit violently. **/
inline static void fatalerr(char const *func, char const *fmt, ...)
{
	va_list vl;
	va_start(vl, fmt);
	fprintf(stderr, "platform-server (%s): ", func);
	vfprintf(stderr, fmt, vl);
	va_end(vl);
	fprintf(stderr, "\nerror: %s", strerror(errno));
	platform_stop(0);
}

/** Send an ack via given socket. **/
static void ack(int conn_sock)
{
	unsigned char buf = ACK;
	if (send(conn_sock, &buf, sizeof(buf), 0) != sizeof(buf))
		FATAL("could not send ack");
}

/** Wait for an ack via given socket. **/
static int recv_ack(int conn_sock)
{
	unsigned char buf = 0;
	return recv(conn_sock, &buf, sizeof(buf), 0) == sizeof(buf)
		&& buf == ACK;
}

/* internal transaction ids */
static unsigned int t_ids[MAX_ID] = {0};

/** Returns the next valid transaction id. */
unsigned int platform_transaction_id(void)
{
	static unsigned int t_id = 0;
	unsigned tid = 0;
	do {
		tid = __atomic_fetch_add(&t_id, 1, __ATOMIC_SEQ_CST) & ID_BITMASK;
	} while (__atomic_test_and_set(&t_ids[tid], __ATOMIC_SEQ_CST));
	return tid;
}

/** Returns a transaction id to the pool of valid ids. */
int platform_transaction_done(unsigned int const id)
{
	// dbgprint("transaction id #%u returned", id & ID_BITMASK);
	__atomic_clear(&t_ids[id & ID_BITMASK], __ATOMIC_SEQ_CST);
	return 0;
}

/** Returns the number of hardware threads supported by this implementation.
    Called from SystemVerilog. */
unsigned int platform_thread_count()
{
	return 48;
}

/******************************************************************************/
/* Parse command implementations. */

static int parse_platform_connect(int conn_sock)
{
	LOG(LPLL_INIT, "received hello, ack'ing");
	ack(conn_sock);
	return 1;
}

static int parse_platform_finish(int conn_sock)
{
	LOG(LPLL_INIT, "exiting");
	ack(conn_sock);
	unsigned int result = 0;
	if (recv(conn_sock, &result, sizeof(result), 0) != sizeof(result)) {
		ERR("failed to receive result");
		return 1;
	}
	ack(conn_sock);
	platform_stop(result);
	return 0;
}

static int parse_platform_get_time(int conn_sock)
{
	LOG(LPLL_INIT, "ack'ing command");
	ack(conn_sock);
	int64_t time = 0;
	platform_get_time(&time);
	LOG(LPLL_INIT, "sending time...");
	if (send(conn_sock, &time, sizeof(time), 0) != sizeof(time)) {
		LOG(LPLL_INIT, "failed to send time");
		return 0;
	}
	LOG(LPLL_INIT, "sent, waiting for client ack...");
	recv_ack(conn_sock);
	LOG(LPLL_INIT, "done");
	return 1;
}

static int parse_platform_wait_cycles(int conn_sock)
{
	int cycles = 0;
	ack(conn_sock);
	if (recv(conn_sock, &cycles, sizeof(cycles), 0) != sizeof(cycles)) {
		ERR("failed to receive cycle count");
		return 0;
	}
	LOG(LPLL_INIT, "%d cycles", cycles);
	platform_wait_cycles(cycles);
	ack(conn_sock);
	return 1;
}

static int parse_platform_read_mem(int conn_sock)
{
	uint32_t start_addr;
	size_t no_of_bytes, i;
	int32_t tmp[16]; // max. AXI3 master burst size
	ack(conn_sock);
	if (recv(conn_sock, &start_addr, sizeof(start_addr), 0) != sizeof(start_addr)) {
		ERR("failed to receive start_addr");
		return 0;
	}
	if (recv(conn_sock, &no_of_bytes, sizeof(no_of_bytes), 0) != sizeof(no_of_bytes)) {
		ERR("failed to receive no_of_bytes");
		return 0;
	}
	ack(conn_sock);
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)start_addr, no_of_bytes);

	const int n = no_of_bytes / sizeof(tmp) + 1;
	for (i = 0; i < n && no_of_bytes; ++i) {
		const size_t cs = no_of_bytes > sizeof(tmp) ? sizeof(tmp) : no_of_bytes;
		const unsigned int tid = platform_transaction_id();
		platform_read_mem(start_addr, cs, tmp, tid);
		platform_transaction_done(tid);
		LOG(LPLL_MEM, "read %zd bytes from 0x%x, sending", cs, start_addr);
		int ret = send(conn_sock, tmp, cs, 0);
		if (ret != cs) {
			ERR("failed to send %zd bytes: %d (%s)", cs, errno, strerror(errno));
			return 0;
		}
		no_of_bytes -= cs;
		start_addr += cs;
		LOG(LPLL_MEM, "%zd bytes sent, %zu bytes left", cs, no_of_bytes);
	}
	LOG(LPLL_MEM, "sending done, waiting for ACK");
	recv_ack(conn_sock);
	LOG(LPLL_MEM, "ACK received, finish");
	return 1;
}

static int parse_platform_write_mem(int conn_sock)
{
	uint32_t start_addr;
	size_t no_of_bytes, i;
	int32_t tmp[16]; // max. AXI3 master burst size
	LOG(LPLL_MEM, "ack'ing command");
	ack(conn_sock);
	if (recv(conn_sock, &start_addr, sizeof(start_addr), 0) != sizeof(start_addr)) {
		ERR("failed to receive start_addr");
		return 0;
	}
	if (recv(conn_sock, &no_of_bytes, sizeof(no_of_bytes), 0) != sizeof(no_of_bytes)) {
		ERR("failed to receive no_of_bytes");
		return 0;
	}
	LOG(LPLL_MEM, "ack'ing args");
	ack(conn_sock);
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)start_addr, no_of_bytes);

	const int n = no_of_bytes / sizeof(tmp) + 1;
	for (i = 0; i < n && no_of_bytes; ++i) {
		const size_t cs = no_of_bytes > sizeof(tmp) ? sizeof(tmp) : no_of_bytes;
		int ret = recv(conn_sock, tmp, cs, 0);
		if (ret != cs) {
			ERR("failed to recv %zd bytes: %d (%s)", cs, errno, strerror(errno));
			return 0;
		}
		LOG(LPLL_MEM, "received %zd bytes, writing to platform", cs);
		const unsigned int tid = platform_transaction_id();
		platform_write_mem(start_addr, cs, tmp, tid);
		platform_transaction_done(tid);
		no_of_bytes -= cs;
		start_addr += cs;
		LOG(LPLL_MEM, "%zd bytes sent, %zu bytes left", cs, no_of_bytes);
	}
	LOG(LPLL_MEM, "finished");
	ack(conn_sock);
	return 1;
}

static int parse_platform_read_ctl(int conn_sock)
{
	uint32_t start_addr;
	size_t no_of_bytes, i;
	int32_t tmp[16]; // max. AXI3 master burst size
	ack(conn_sock);
	if (recv(conn_sock, &start_addr, sizeof(start_addr), 0) != sizeof(start_addr)) {
		ERR("failed to receive start_addr");
		return 0;
	}
	if (recv(conn_sock, &no_of_bytes, sizeof(no_of_bytes), 0) != sizeof(no_of_bytes)) {
		ERR("failed to receive no_of_bytes");
		return 0;
	}
	ack(conn_sock);
	LOG(LPLL_CTL, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)start_addr, no_of_bytes);

	const int n = no_of_bytes / sizeof(tmp) + 1;
	for (i = 0; i < n && no_of_bytes; ++i) {
		const size_t cs = no_of_bytes > sizeof(tmp) ? sizeof(tmp) : no_of_bytes;
		platform_read_ctl(start_addr, cs, tmp);
		LOG(LPLL_CTL, "read %zu bytes from 0x%08lx, sending",
				cs, (unsigned long)start_addr);
		int ret = send(conn_sock, tmp, cs, 0);
		if (ret != cs) {
			ERR("failed to send %zd bytes: %d (%s)", cs, errno, strerror(errno));
			return 0;
		}
		no_of_bytes -= cs;
		start_addr += cs;
		LOG(LPLL_CTL, "%zu bytes sent, %zu bytes left", cs, no_of_bytes);
	}
	LOG(LPLL_CTL, "sending done, waiting for ACK");
	recv_ack(conn_sock);
	LOG(LPLL_CTL, "ACK received, finish");
	return 1;
}

static int parse_platform_write_ctl(int conn_sock)
{
	uint32_t start_addr;
	size_t no_of_bytes, i;
	int32_t tmp[16]; // max. AXI3 master burst size
	LOG(LPLL_CTL, "ack'ing command");
	ack(conn_sock);
	if (recv(conn_sock, &start_addr, sizeof(start_addr), 0) != sizeof(start_addr)) {
		ERR("failed to receive start_addr");
		return 0;
	}
	if (recv(conn_sock, &no_of_bytes, sizeof(no_of_bytes), 0) != sizeof(no_of_bytes)) {
		ERR("failed to receive no_of_bytes");
		return 0;
	}
	LOG(LPLL_CTL, "ack'ing args");
	ack(conn_sock);
	LOG(LPLL_CTL, "start_addr = 0x%x, no_of_bytes = %zu", start_addr, no_of_bytes);

	const int n = no_of_bytes / sizeof(tmp) + 1;
	for (i = 0; i < n && no_of_bytes; ++i) {
		const size_t cs = no_of_bytes > sizeof(tmp) ? sizeof(tmp) : no_of_bytes;
		int ret = recv(conn_sock, tmp, cs, 0);
		if (ret != cs) {
			ERR("failed to recv %zd bytes: %d (%s)", cs, errno, strerror(errno));
			return 0;
		}
		LOG(LPLL_CTL, "received %zd bytes, writing to platform", cs);
		platform_write_ctl(start_addr, cs, tmp);
		no_of_bytes -= cs;
		start_addr += cs;
		LOG(LPLL_CTL, "%zd bytes sent, %zu bytes left", cs, no_of_bytes);
	}
	LOG(LPLL_CTL, "finished");
	ack(conn_sock);
	return 1;
}

static int parse_platform_wait_for_event(int conn_sock)
{
	uint32_t event;
	LOG(LPLL_CTL, "ack'ing command");
	ack(conn_sock);
	if (recv(conn_sock, &event, sizeof(event), 0) != sizeof(event)) {
		ERR("failed to receive event");
		return 0;
	}
	LOG(LPLL_CTL, "ack'ing args");
	ack(conn_sock);
	LOG(LPLL_CTL, "event = 0x%x", event);
	platform_wait_for_event(event);
	LOG(LPLL_CTL, "finished");
	ack(conn_sock);
	return 1;
}

static int parse_platform_write_ctl_and_wait(int conn_sock)
{
	uint32_t w_addr, event;
	size_t w_no_of_bytes;
	int32_t tmp[16]; // max. AXI3 master burst size
	LOG(LPLL_CTL, "ack'ing command");
	ack(conn_sock);
	if (recv(conn_sock, &w_addr, sizeof(w_addr), 0) != sizeof(w_addr)) {
		ERR("failed to receive w_addr");
		return 0;
	}
	if (recv(conn_sock, &w_no_of_bytes, sizeof(w_no_of_bytes), 0) != sizeof(w_no_of_bytes)) {
		ERR("failed to receive w_no_of_bytes");
		return 0;
	}
	if (recv(conn_sock, &event, sizeof(event), 0) != sizeof(event)) {
		ERR("failed to receive event");
		return 0;
	}
	LOG(LPLL_CTL, "ack'ing args");
	ack(conn_sock);
	LOG(LPLL_CTL, "w_addr = 0x%x, w_no_of_bytes = %zu, event number = %u",
			w_addr, w_no_of_bytes, event);

	if (w_no_of_bytes > sizeof(tmp)) {
		ERR("invalid size %zu bytes, can only transfer %zd bytes",
				w_no_of_bytes, sizeof(tmp));
		return 0;
	}

	int ret = recv(conn_sock, tmp, w_no_of_bytes, 0);
	if (ret != w_no_of_bytes) {
		ERR("failed to recv %zu bytes: %d (%s)", w_no_of_bytes, errno, strerror(errno));
		return 0;
	}
	LOG(LPLL_CTL, "received %zu bytes, writing to platform", w_no_of_bytes);
	platform_write_ctl_and_wait(w_addr, w_no_of_bytes, tmp, event);
	LOG(LPLL_CTL, "platform_write_ctl_and_wait finished");
	ack(conn_sock);
	return 1;
}

/******************************************************************************/

/** Parses a command received via conn_sock and calls the corr. parser func. **/
static int parse_cmd_nb(int conn_sock)
{
	unsigned char buf;
	// dbgprint("waiting for next command ...");
	if (recv(conn_sock, &buf, sizeof(buf), MSG_DONTWAIT) == sizeof(buf)) {
		LOG(LPLL_INIT, "received byte: %d (0x%02x)", buf, buf);
		#ifdef _X
			#undef _X
		#endif
		#define _X(name, val, len, parser) if (buf == name) parser(conn_sock);
		COMMANDS
		#undef _X
		LOG(LPLL_INIT, "command %d (0x%02x) done", buf, buf);
	}
	return 1;
}

/******************************************************************************/
/* Interface toward SV simulator */

static long open_socket_conn(unsigned int const idx)
{
	LOG(LPLL_INIT, "init, opening socket #%d", idx);
	assert(idx < MAX_SOCKETS);
	master_sock[idx] = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
	if (master_sock[idx] == -1) {
		ERR("could not create master socket #%u", idx);
		return errno;
	}

	char socket_path[1024];
	snprintf(socket_path, 1023, "%s_%03u", getenv("LIBPLATFORM_DPI_SOCKET") ?
		getenv("LIBPLATFORM_DPI_SOCKET") : "LIBPLATFORM_DPI", idx);

	struct sockaddr_un local;
	LOG(LPLL_INIT, "init, setting up bind for socket '%s'", socket_path);
	local.sun_family = AF_UNIX;
	strcpy(local.sun_path, socket_path);
	unlink(local.sun_path);
	unsigned int len = strlen(local.sun_path) + sizeof(local.sun_family);

	if (bind(master_sock[idx], (struct sockaddr *) &local, len)) {
		ERR("could not bind socket #%u", idx);
		return errno;
	}

	if (listen(master_sock[idx], 1)) {
		ERR("could not change socket #%u into listening mode", idx);
		return errno;
	}

	LOG(LPLL_INIT, "init done, waiting for connections");

	struct sockaddr_un remote;
	int attempts = 20;
	do {
		conn_sock[idx] = accept(master_sock[idx], (struct sockaddr*) &remote, &len);
		if (conn_sock[idx] == -1) {
			--attempts;
			LOG(LPLL_INIT, "no client connection, making %d more attempts ...", attempts);
			sleep(1);
		}
	} while (attempts && conn_sock[idx] == -1);

	if (conn_sock[idx] == -1) {
		ERR("could not accept client connection on socket #%u", idx);
		return -1;
	}
	LOG(LPLL_INIT, "connection established, init done");
	pthread_mutex_unlock(&conn_sock_lock[idx]);
	return 0;
}

static void *run_connect(void *p)
{
	long unsigned const s_id = (long unsigned)p;
	LOG(LPLL_INIT, "init of thread %lu", s_id);
	return (void *)open_socket_conn(s_id);
}

int platform_init(unsigned int thrdidx)
{
	int err = 0;
	pthread_t t[platform_thread_count()];
	int       r[platform_thread_count()];

	platform_logging_init();
	for (int i = 0; i < MAX_ID; ++i)
		platform_transaction_done(i);
	for (int i = 0; i < MAX_SOCKETS; ++i) {
		err += pthread_mutex_init(&conn_sock_lock[i], NULL);
		err += pthread_mutex_lock(&conn_sock_lock[i]);
	}
	if (! err) {
		for (long i = 0; i < platform_thread_count(); ++i)
			pthread_create(&t[i], NULL, run_connect, (void *)i);
		for (long i = 0; i < platform_thread_count(); ++i)
			pthread_join(t[i], (void *)&r[i]);
		for (long i = 0; i < platform_thread_count(); ++i)
			err += r[i];
	}
	LOG(LPLL_INIT, "libplatform init done, result: %d", err);
	if (err)
		FATAL("platform_init failed, check log!");
	return err ? 1 : 0;
}

int platform_deinit()
{
	for (int s = 0; s < MAX_SOCKETS; ++s) {
		pthread_mutex_destroy(&conn_sock_lock[s]);
		close(conn_sock[s]);
		close(master_sock[s]);
	}

	LOG(LPLL_INIT, "deinit done, bye!");
	platform_logging_exit();
	return 0;
}

int platform_run(unsigned int const thrdidx)
{
	unsigned int const s_id = thrdidx % MAX_SOCKETS;
	if (pthread_mutex_trylock(&conn_sock_lock[s_id]) == 0) {
		parse_cmd_nb(conn_sock[s_id]);
		pthread_mutex_unlock(&conn_sock_lock[s_id]);
	} // else LOG(LPLL_INIT, "socket #%u is blocked", s_id);
	return 0;
}

int platform_irq_handler()
{
	int32_t irq[MAX_INTC * 16] = {0};
	LOG(LPLL_IRQ, "irq handler");
	for (int i = 0; i < MAX_INTC; ++i) {
		platform_read_ctl(INTC_BASE + i * INTC_OFFS, sizeof(irq[i]), &irq[i]);
		LOG(LPLL_IRQ, "found irq[%d] = 0x%08x", i, irq[i]);
		if (irq[i])
			// ack the irq
			platform_write_ctl(INTC_BASE + i * INTC_OFFS + 0xc, sizeof(irq[i]), &irq[i]);
	}

	for (int i = 0; i < MAX_INTC; ++i) {
		for (unsigned int slot_id = 0; irq[i] && slot_id < 32; ++slot_id) {
			unsigned int const d = 1 << slot_id;
			if (irq[i] & d) {
				irq[i] &= ~d;
				// then trigger platform event
				LOG(LPLL_IRQ, "triggering event #%u", slot_id);
				platform_trigger_event(slot_id + i * 32);
			}
		}
	}
	return 0;
}

int unsigned platform_clock_period()
{
	static int unsigned period = 0;
	if (! period) {
		const char *freq = getenv("TPC_FREQ");
		if (! freq) {
			WRN("environment variable TPC_FREQ is not set, assuming 250 MHz!");
			period = 4;
		} else {
			period = 1000 / strtoul(freq, NULL, 0);
		}
		LOG(LPLL_INIT, "clock period = %u ns", period);
	}
	return period;
}

