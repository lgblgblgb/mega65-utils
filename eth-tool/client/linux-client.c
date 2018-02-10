/*
	** A work-in-progess Mega-65 (Commodore-65 clone origins) emulator
	** Part of the Xemu project, please visit: https://github.com/lgblgblgb/xemu
	** Copyright (C)2018 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>

This is a client for eth-tool running on Mega-65, so you can access
some funtionality via Ethernet network from your "regular" computer.

*** Also uses code from BUSE, see source file buse.c

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */



#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netdb.h> 
#include <errno.h>
#include <time.h>
#include <sys/time.h>
#ifdef USE_BUSE
#include "buse.h"
#endif
#ifdef USE_READLINE
#include <readline/readline.h>
#include <readline/history.h>
#endif


#define MAX_MTU_INITIAL 1472
#define RETRANSMIT_TIMEOUT_USEC	500000
#define M65_IO_ADDR(a)    (((a)&0xFFF)|0xFFD3000)
#define SD_STATUS_SDHC_FLAG 0x10
#define SD_STATUS_ERROR_MASK (0x40|0x20)

static struct {
	int mtu_size, header_overhead, mtu_changed;
	int sock;
	int in_progress_msg;
	unsigned char s_buf[MAX_MTU_INITIAL], *s_p;
	unsigned char r_buf[MAX_MTU_INITIAL];
	int s_size, r_size, ans_size_expected, m65_size;
	int round_trip_usec;
	int retransmissions;
	int retransmit_timeout_usec;
	int sdhc;
	int sdsize;
	int sdstatus;
	unsigned char *sector;
	int debug;
	int has_answer;
} com;



#ifdef USE_BUSE
// prototypes, since we want these to be defined later, quite messed up source ;-P
// TODO: split up, structure the M65-client source in the future ...
static int sd_read_sector  ( unsigned int sector );
static int sd_write_sector ( unsigned int sector, unsigned char *data );

static int nbd_debug;

static int nbd_op_read(void *buf, u_int32_t len, u_int64_t offset, void *userdata)
{
	if (*(int *)userdata)
		fprintf(stderr, "R - %lu, %u\n", offset, len);
	// WARNING IT'S MAYBE NOT WORKS (DENYING UNALIGNED ACCESS)
	// Also - in my opinion - it shouldn't happen!!! Well, hopefully ...
	if ((len & 511)) {
		fprintf(stderr, "NBD: ERROR: Length is not multiple of 512\n");
		return htonl(EINVAL);
	}
	if ((offset & 511UL)) {
		fprintf(stderr, "NBD: ERROR: Offset is not 512-byte aligned\n");
		return htonl(EINVAL);
	}
	// For real, we handle only sector level offset and length.
	// So mangle our input to reflect starting sector and number of sectors as offset
	// even if the variable names are mis-leading from this point already
	len >>= 9;
	offset >>= 9;
	while (len--) {
		int ret;
		if (offset >= com.sdsize) {
			fprintf(stderr, "NBD: trying to read beyond the end of device.\n");
			return htonl(EFBIG);
		}
		// TODO: in case of multiple sectors, we should group by two, in one request/answer, to speed things up maybe two-fold
		// more than two is not possible wouldn't fit into the MTU of Ethernet already (even two can be problem if this is done
		// through some 'remote' connection supporting only smaller MTU size for path MTU).
		ret = sd_read_sector(offset++);
		if (ret)	// TODO: if ret == -2, give specific error on access beyond end of the device! and remove the 'if' above since that redundant to check here as well.
			return htonl(EIO);
		memcpy(buf, com.sector, 512);
		buf += 512;
	}
	return 0;
}

static int nbd_op_write(const void *buf, u_int32_t len, u_int64_t offset, void *userdata)
{
	if (*(int *)userdata)
		fprintf(stderr, "W - %lu, %u\n", offset, len);
	return htonl(EPERM);	// writing is not yet supported ...
	//return -1;	// writing is not yet supported ...
}

static void nbd_op_disc(void *userdata)
{
	(void)(userdata);
	fprintf(stderr, "Received a disconnect request.\n");
}

static int nbd_op_flush(void *userdata)
{
	(void)(userdata);
	fprintf(stderr, "Received a flush request.\n");
	return 0;
}

static int nbd_op_trim(u_int64_t from, u_int32_t len, void *userdata)
{
	(void)(userdata);
	fprintf(stderr, "T - %lu, %u\n", from, len);
	return 0;
}


static struct buse_operations aop = {
	.read	= nbd_op_read,
	.write	= nbd_op_write,
	.disc	= nbd_op_disc,
	.flush	= nbd_op_flush,
	.trim	= nbd_op_trim,
	// either set size, OR set both blksize and size_blocks
	//.size = 128 * 1024 * 1024,
	// either set size, OR set both blksize and size_blocks
	// LGB: according to my test, everything should be set if blksize is set, or segfault happens!
	// THESE VALUES ARE OVERRIDEN BY size detection, do not worry about them here :) :)
	.blksize = 512,
	.size_blocks = 512 * 1024,
	.size = 512*512*1024
};
#endif





static int m65_send ( void *buffer, int len )
{
	com.mtu_changed = 0;
	for (;;) {
		int ret;
		socklen_t pl;
		if (len > com.mtu_size) {
			fprintf(stderr, "SEND: Too long message (%d), over PMTU (%d)\n", len, com.mtu_size);
			return -1;
		}
		//pl = sizeof(com.serveraddr);
		ret = send(
			com.sock,
			buffer,
			len,
			0//,
			//(struct sockaddr *)&com.serveraddr,
			//sizeof(com.serveraddr)
		);
		if (ret == -1) {
			if (errno == EINTR)
				continue;
			if (errno == EMSGSIZE) {
				int mtu_old = com.mtu_size;
				// query MTU after an EMSGSIZE error
				pl = sizeof(com.mtu_size);
				if (getsockopt(com.sock, IPPROTO_IP, IP_MTU, &com.mtu_size, &pl) == -1) {
					perror("SEND: getsockopt(IPPROTO_IP, IP_MTU)");
					return -1;
				}
				com.mtu_size -= com.header_overhead;
				com.mtu_changed = 1;
				printf("SEND: note: MTU(-header_overhead=-%d) is now %d bytes (was: %d)\n", com.header_overhead, com.mtu_size, mtu_old);
				return -1;
			}
			perror("SEND: sendto() failed");
			return -1;
		}
		if (ret != len) {
			fprintf(stderr, "SEND: cannot send %d bytes, only %d\n", len, ret);
			return -1;
		}
		return ret;
	}
}



static int m65_con_init ( const char *hostname, int port )
{
	int val;
	struct hostent *server;
        struct sockaddr_in serveraddr;
	com.sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (com.sock < 0) {
		perror("Opening socket");
		return -1;
	}
	server = gethostbyname(hostname);
	if (!server) {
		fprintf(stderr,"Cannot resolve name '%s' or other error: %s\n", hostname, hstrerror(h_errno));
		close(com.sock);
		return -1;
	}
	com.mtu_size = 1400;	// some value
	com.mtu_changed = 0;
	com.retransmissions = 0;
	com.retransmit_timeout_usec = RETRANSMIT_TIMEOUT_USEC;
	com.sdhc = -1;
	com.sdsize = -1;
	com.header_overhead = 28;
	com.debug = 0;
	com.sdstatus = 0xFF;
	com.sector = NULL;
	com.in_progress_msg = 0;
	printf("Sending to server: (%s) %u.%u.%u.%u:%d with initial MTU of %d bytes ...\n",
		hostname,
		server->h_addr[0] & 0xFF,
		server->h_addr[1] & 0xFF,
		server->h_addr[2] & 0xFF,
		server->h_addr[3] & 0xFF,
		port,
		com.mtu_size
	);
	memset(&serveraddr, 0, sizeof(serveraddr));
	serveraddr.sin_family = AF_INET;
	memcpy(&serveraddr.sin_addr.s_addr, server->h_addr, server->h_length);
	serveraddr.sin_port = htons(port);
	// Actually not a "connect" in case of UDP, just to save specify parameters all the
	// the time at sendto() so we can use send() as well.
	if (connect(com.sock, (struct sockaddr *)&serveraddr, sizeof(serveraddr))) {
		perror("connect()");
		close(com.sock);
		return -1;
	}
	// Setting PATH MTU discovery. Initial packets may be dropped!
	// Forces any packets set DF bit, and Linux kernel to refuse
	// to send, if packet is larger than the succussfully done
	// PMTU discovery with error code of EMSGSIZE
	// No idea how it works on other OS'es ...
	// Note, it can cause to have lost sents at the beginning at least.
	// We exactly want this, only sending packets are not / cannot be fragmented.
	val = IP_PMTUDISC_DO;
	if (setsockopt(com.sock, IPPROTO_IP, IP_MTU_DISCOVER, &val, sizeof(val)) == -1) {
		perror("setsockopt(sock, IPPROTO_IP, IP_MTU_DISCOVER)");
		close(com.sock);
		return -1;
	}
	return 0;
}


static void hex_dump ( unsigned const char *buffer, int size, const char *comment, int print_addr_offset )
{
	char ascii[17];
	int i = 0;
	ascii[16] = 0;
	printf("DUMP[%s; %d bytes]:\n", comment, size);
	while (i < size) {
		unsigned char c = buffer[i];
		if (!(i & 15)) {
			if (i) {
				printf("  %s", ascii);
				putchar('\n');
			}
			printf("  %07X  ", i + print_addr_offset);
		}
		printf(" %02X", c);
		ascii[i & 15] = (c >= 32 && c < 127) ? c : '.';
		i++;
	}
	if ((i & 15))
		ascii[i & 15] = 0;
	while ((i++ & 15))
		printf("   ");
	printf("  %s", ascii);
	putchar('\n');
}


static void already_in_progress_assert ( int should_be, const char *additional_debug_info )
{
	if (com.in_progress_msg == should_be)
		return;
	fprintf(stderr, "**** FATAL ERROR: com.in_progress_msg should be %d, but we have %d: %s\n",
		should_be, com.in_progress_msg, additional_debug_info
	);
	exit(1);	// is that fatal enough for us? ;-P
}


// Start to construct a new monitor port request
static void msg_begin ( void )
{
	already_in_progress_assert(0, "msg_begin()");
	com.in_progress_msg = 1;
	com.s_buf[0] = 0;
	com.s_buf[1] = 'M';
	com.s_buf[2] = '6';
	com.s_buf[3] = '5';
	com.s_buf[4] = '*';
	com.s_p = com.s_buf + 5;
	com.ans_size_expected = 8;	// expected base size is 8:  marker=5 + size=2 + status=1
}

static int msg_add_readmem ( int m65_addr, int size )
{
	int expected_answer_pos;
	already_in_progress_assert(1, "msg_add_readmem()");
	expected_answer_pos = com.ans_size_expected;
	com.ans_size_expected += size;		// answer should contain these amount of bytes!
	*com.s_p++ = 1;			// command code: read memory
	*com.s_p++ = size & 0xFF;		// length low byte
	*com.s_p++ = size >> 8;		// length hi byte
	*com.s_p++ = m65_addr & 0xFF;		// 4 byte of M65 address
	*com.s_p++ = (m65_addr >> 8) & 0xFF;
	*com.s_p++ = (m65_addr >> 16) & 0xFF;
	*com.s_p++ = (m65_addr >> 24) & 0x0F;	// only 28 bits on M65
	return expected_answer_pos;
}

static int msg_add_waitsd ( void )
{
	already_in_progress_assert(1, "msg_add_waitsd()");
	*com.s_p++ = 5;	// command 5, has no params
	return (com.ans_size_expected++);	// but extends the answer with one byte
}

static void msg_add_writemem ( int m65_addr, int size, unsigned char *buffer )
{
	already_in_progress_assert(1, "msg_add_writemem()");
	// write does not extend the answer size at all!
	*com.s_p++ = 2;			// command code: write memory
	*com.s_p++ = size & 0xFF;		// length low byte
	*com.s_p++ = size >> 8;		// length hi byte
	*com.s_p++ = m65_addr & 0xFF;		// 4 byte of M65 address
	*com.s_p++ = (m65_addr >> 8) & 0xFF;
	*com.s_p++ = (m65_addr >> 16) & 0xFF;
	*com.s_p++ = (m65_addr >> 24) & 0x0F;	// only 28 bits on M65
	// Now also add the data as well to be written on the M65 size
	// dangerous: zero should be currently NOT used!
	memcpy(com.s_p, buffer, size);
	com.s_p += size;
}

static int msg_commit ( void )
{
	struct timeval tv1, tv2;
	int retrans_here;
	fd_set readfds;
	already_in_progress_assert(1, "msg_commit()");
	*com.s_p++ = 3;	// close the list of commands!!!!!
	com.s_size = com.s_p - com.s_buf;	// calculate our request's total size
	if (com.debug)
		hex_dump(com.s_buf, com.s_size, "REQUEST TO SEND", 0);
	gettimeofday(&tv1, NULL);
	com.in_progress_msg = 0;
	com.has_answer = 0;

	retrans_here = 0;
retransmit:

	// SEND. FIXME: maybe we should use select() and non blocking I/O to detect OS problem(s) on sending?
	if (m65_send(com.s_buf, com.s_size) <= 0) {
		fprintf(stderr, "m65_send() returned with error :-(\n");
		return -1;
	}

	// Receive answer, with timeout.
	// Note: monitor MUST always reply and we want that to notice! We can't send newer if it's not the case!
	// We should re-transmit our request on some certain timeout.
	// It's ugly now, maybe proper non-blocking I/O should be used, not blocking I/O + select() ...
	// According my performance test, reading 1000 sectors, no retransmission was needed (ie no UDP packet lost)
	// so maybe it's more a robust-stuff, rather than too much needed, but anyway.

reselect:

	tv2.tv_sec = 0;
	tv2.tv_usec = com.retransmit_timeout_usec;
	FD_ZERO(&readfds);
	FD_SET(com.sock, &readfds);
	if (select(com.sock + 1, &readfds, NULL, NULL, &tv2) < 0) {
		if (errno == EINTR)
			goto reselect;
		perror("select()");
		return -1;
	}
	if (!FD_ISSET(com.sock, &readfds)) {
		com.retransmissions++;
		retrans_here++;
		if (com.debug)
			printf("Receive timed out, retransmission (#%d) of the request ...\n", retrans_here);
		goto retransmit;
	}
	// *** receive ***

rerecv:

	com.r_size = recv(com.sock, com.r_buf, com.mtu_size, 0);
	gettimeofday(&tv2, NULL);
	com.round_trip_usec = (tv2.tv_sec - tv1.tv_sec) * 1000000 + (tv2.tv_usec - tv1.tv_usec);
	if (com.debug)
		printf("Request-answer round-trip in msecs: %f\n", com.round_trip_usec / 1000.0);
	if (com.r_size < 0) {
		if (errno == EINTR)
			goto rerecv;
		perror("recv()");
		return -1;
	}
	if (com.r_size == 0) {
		fprintf(stderr, "recv() returned with zero size!\n");
		return -1;
	}
	com.has_answer = 1;
	if (com.debug)
		hex_dump(com.r_buf, com.r_size, "RECEIVED ANSWER", 0);
	if (com.r_size < 8) {
		fprintf(stderr, "Abnormally short answer, at least 8 bytes, we got %d\n", com.r_size);
		return -1;
	}
	if (com.r_buf[0] || com.r_buf[1] != 'M' || com.r_buf[2] != '6' || com.r_buf[3] != '5' || com.r_buf[4] != '*') {
		fprintf(stderr, "Magic marker cannot be found in the answer!\n");
		return -1;
	}
	com.m65_size = com.r_buf[5] + (com.r_buf[6] << 8);
	if (com.m65_size != com.r_size) {
		fprintf(stderr, "Internal mismtach, received size (%d) is not the same what the answer states (%d) to be\n", com.r_size, com.m65_size);
		return -1;
	}
	if (com.r_buf[7]) {
		fprintf(stderr, "eth-tool monitor on M65 reports error, error code = $%02X\n", com.r_buf[7]);
		return -1;
	}
	if (com.r_size != com.ans_size_expected) {
		fprintf(stderr, "answer size mismatch, got %d bytes, request expected %d bytes as answer\n", com.r_size, com.ans_size_expected);
		return -1;
	}
	if (com.debug)
		printf("WOW, answer seems to be OK ;-)\n");
	return 0;
}


static int sd_reset ( void )
{
	unsigned char byteval;
	int stindex1, stindex2, stindex3;
	printf("Resetting SD ...\n");
	msg_begin();
	// Send SD command 0: reset
	byteval = 0x00;
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, &byteval);
	// Wait for being ready, read status
	stindex1 = msg_add_waitsd();
	// Send SD command 1: end-reset
	byteval = 0x01;
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, &byteval);
	// Wait for being ready, read status
	stindex2 = msg_add_waitsd();
	// Just to be sure, we issue SDHC setting in the case if RESET would mess it up ...
	// TODO: is this really needed, or is it safe to ignore?
	// NOTE: mega65-fdisk source says, write may not work without this, even when SDHC bit not changed. So we leave this here!
	byteval = com.sdhc ? 0x41 : 0x40;	// SDHC mode on/off based on the previous state
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, &byteval);
	// Again, we wait and read status ...
	stindex3 = msg_add_waitsd();
	// Commit our chained sequence of monitor commands expressed above starting with msg_begin()
	if (msg_commit()) {
		fprintf(stderr, "Error in communication while issuing the RESET sequence ...\n");
		return -1;
	}
	printf("  RESET STAT: after cmd-reset = $%02X(err=$%02X), after cmd-end-reset = $%02X(err=$%02X), after cmd-sdhc-set/reset = $%02X(err=$%02X)\n",
		com.r_buf[stindex1], com.r_buf[stindex1] & SD_STATUS_ERROR_MASK,
		com.r_buf[stindex2], com.r_buf[stindex2] & SD_STATUS_ERROR_MASK,
		com.r_buf[stindex3], com.r_buf[stindex3] & SD_STATUS_ERROR_MASK
	);
	if ((com.r_buf[stindex3] & SD_STATUS_SDHC_FLAG) != com.sdhc) {
		fprintf(stderr, "FATAL ERROR: SDHC flag changed during the reset????\n");
		return -1;
	}
	com.sdstatus = com.r_buf[stindex3];
	// it seems M65 always reports error no matter how hard I try reset ...
	// but it also seems that next read will be OK ...
	// so just fake that status does not contain error condition anymore :-O
	com.sdstatus &= ~SD_STATUS_ERROR_MASK;
	return 0;

#if 0
	unsigned char byteval;
	int status_index;
	int save_debug;
	save_debug = com.debug;
	//com.debug = 1;
	printf("Resetting SD ...\n");
	// Resetting SD is needed after an error, so it can't be a very popular case (in size detection it's done by WILL!)
	// To simplify things and give some time between reset and end-reset, we simply use TWO network "transactions",
	// that would be already itself gives something like 500 usec at minimum, but probably even more.
	// -- send reset --
	printf("... sending RESET command\n");
	msg_begin();
	byteval = 0x00;
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, &byteval);
	if (msg_commit()) {
		fprintf(stderr, "Error while resetting SD ...\n");
		com.debug = save_debug;
		return -1;
	}
	// TODO: implement reset in one communication step, with waiting to be ready.
	// -- send end reset --
	printf("... sending END-RESET command\n");
	msg_begin();
	byteval = 0x01;
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, &byteval);
	status_index = msg_add_waitsd();
	if (msg_commit()) {
		fprintf(stderr, "Error while end-resetting SD ...\n");
		com.debug = save_debug;
		return -1;
	}
	// -- send a SEPARATE message for status ... ---
	printf("... query status\n");
	msg_begin();
	status_index = msg_add_waitsd();
	if (msg_commit()) {
		fprintf(stderr, "Error while querying status byte ...\n");
		com.debug = save_debug;
		return -1;
	}
	// See what we have ...
	if ((com.r_buf[status_index] & SD_STATUS_SDHC_FLAG) != com.sdhc) {
		fprintf(stderr, "Fatal error: SDHC flag changed during reset process!\n");
		exit(1);	// REALLY FATAL!
		com.debug = save_debug;
		return -1;
	}
	com.sdstatus = com.r_buf[status_index];
	if ((com.sdstatus & SD_STATUS_ERROR_MASK)) {
		fprintf(stderr, "Fatal [??????] error: SD still reports error condition after reset!\n");
		com.debug = save_debug;
		return -1;
	}
	printf("Reset process seems to be OK, flag = $%02X\n", com.sdstatus);
	com.debug = save_debug;
	return 0;
#endif
}



// This functions asks M65 about the SD-card status to discover the card is SDHC or not
// It caches the result locally, only used once! Still, this function should be called
// before EVERY sector read/write, to be sure, we handle SDHC/non-SDHC situation well.
// Do not worry, as I've stated, the result is cached, won't cause to ask M65 via network
// every time, only the first time.
// Retrurn valus is NOT the status, but error condition. com.sdhc is what we're looking for.
// DO CALL THIS ROUTINE ONLY OUTSIDE OF A MESSAGE CREATION PROCESS! IT CREATES ITS OWN MESSAGE
// TO GET STATUS!
static int sd_get_sdhc ( void )
{
	int sd_status_index;
	if (com.sdhc != -1)
		return 0;
	printf("Sending message to read SD-status for the SDHC flag ...\n");
	msg_begin();
	sd_status_index = msg_add_waitsd();
	if (msg_commit())
		return -1;
	com.sdstatus = com.r_buf[sd_status_index];
	com.sdhc = (com.sdstatus & SD_STATUS_SDHC_FLAG);
	printf("SD-card SDHC flag: %s (error condition is: $%02X, full status flag is $%02X)\n", com.sdhc ? "ON" : "OFF", com.sdstatus & SD_STATUS_ERROR_MASK, com.sdstatus);
	if ((com.sdstatus & SD_STATUS_ERROR_MASK))
		return sd_reset();
	return 0;
}


// see sd_read_sector for some additional comments
static int sd_write_sector ( unsigned int sector, unsigned char *data )
{
	unsigned char buffer[6];
	int sd_status_index1, sd_status_index2, sd_data_index;
	com.sector = NULL;
	if (sd_get_sdhc())
		return -1;
	if (com.sdsize != -1 && sector >= com.sdsize) {
		fprintf(stderr, "Writing sector above the media size (%d, max_sectors=%d)!\n", sector, com.sdsize);
		return -2;
	}
	if (!com.sdhc) {
		if (sector >= 0x800000) {
			fprintf(stderr, "Writing sector %X would result in invalid byte offset in non-SDHC mode!\n", sector);
			return -2;
		}
		sector <<= 9U;
	}
	buffer[0] = sector & 0xFF;
	buffer[1] = (sector >> 8) & 0xFF;
	buffer[2] = (sector >> 16) & 0xFF;
	buffer[3] = (sector >> 24) & 0xFF;
	msg_begin();
	// --- write I/O area with sector number
	msg_add_writemem(M65_IO_ADDR(0xD681), 4, buffer);
	// --- fill sector buffer with out data
	msg_add_writemem(0xFFD6E00, 512, data);
	// --- give our write command
	buffer[4] = 3;
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, buffer + 4);
	// --- wait for ready + read status
	sd_status_index1 = msg_add_waitsd();
	// --- corrupt SD sector buffer by will, so we can detect what happens on read-back ...
	buffer[4] = data[0] ^ 0xFF;
	msg_add_writemem(0xFFD6E00, 1, buffer + 4);
	// --- read block back
	buffer[4] = 2;	// read command
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, buffer + 4);	// also, we want to read result back ...
	// --- wait for ready + read status
	sd_status_index2 = msg_add_waitsd();
	// --- read SD sector buffer, so we can test the result
	sd_data_index = msg_add_readmem(0xFFD6E00, 512);
	if (msg_commit())
		return -1;
	

	memcmp(data, com.r_buf + sd_data_index, 512);
	//com.sdstatus = com.r_buf[sd_status_index];
}



static int sd_read_sector ( unsigned int sector )
{
	unsigned char buffer[6];
	int sd_status_index, sd_data_index;
	com.sector = NULL;
	// sets com.sdhc, if it wasn't before
	if (sd_get_sdhc())
		return -1;
	if (com.sdsize != -1 && sector >= com.sdsize) {
		fprintf(stderr, "Reading sector above the media size (%d, max_sectors=%d)!\n", sector, com.sdsize);
		return -2;
	}
	// We always want to use plain sector addressing.
	// So, we check SDHC bit of status, and if it is not set,
	// we convert "sector" to byte addressing here. The caller
	// of this function doesn't need to know anoything this
	if (!com.sdhc) {
		if (sector >= 0x800000) {
			fprintf(stderr, "Reading sector %X would result in invalid byte offset in non-SDHC mode!\n", sector);
			return -2;
		}
		sector <<= 9U;
	}
	buffer[0] = sector & 0xFF;
	buffer[1] = (sector >> 8) & 0xFF;
	buffer[2] = (sector >> 16) & 0xFF;
	buffer[3] = (sector >> 24) & 0xFF;
	buffer[4] = 2;		// read block command for M65 SD controller
	msg_begin();
	msg_add_writemem(M65_IO_ADDR(0xD681), 4, buffer);
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, buffer + 4);
	sd_status_index = msg_add_waitsd();
	// we want to read the SD-card buffer in the answer (even there is an error - see status -, then we don't use it, but better than using TWO messages/transmission rounds ...)
	sd_data_index = msg_add_readmem(0xFFD6E00, 512);
	// ---- COMMIT MESSAGE, WAITING FOR ANSWER ----
	if (msg_commit())
		return -1;
	com.sdstatus = com.r_buf[sd_status_index];
	//if ((com.sdstatus & SD_STATUS_ERROR_MASK)) {
	//	sd_reset();
	//}
	if ((com.sdstatus & SD_STATUS_SDHC_FLAG) != com.sdhc) {
		fprintf(stderr, "Fatal error: SDHC flag has changed?!\n");
		return -1;
	}
	if ((com.sdstatus & SD_STATUS_ERROR_MASK)) {
		fprintf(stderr, "Cannot read SD-sector, SD controller reported some error condition (status=$%02X)\n", com.sdstatus);
		if (sd_reset()) {
			//return -1;
			return 1;
		}
		return 1;
	} else {
		// sector buffer is only valid, if status found OK.
		com.sector = com.r_buf + sd_data_index;
		return 0;
	}
}


static void print_sd_size ( void )
{
	if (com.sdsize == -1)
		fprintf(stderr, "Cannot show SD size since detection was not completed yet!\n");
	else
		printf("Detected card size is %d sectors in total ~ %d Mbyte\n",
			com.sdsize, com.sdsize >> 11
		);
}


static int sd_get_size ( void )
{
	unsigned int mask, size;
	if (com.sdsize != -1)
		return 0;	// cached value already in "com" struct
	printf("Detecting card size is in progress ...\n");
	// Reading sector zero is for just getting SDHC flag, and also initial test, that we can read at all!
	printf("Reading sector 0 for testing ...\n");
	if (sd_read_sector(0))
		return -1;
	if (com.sdhc) {
		//mask = 0x80000000U;
		mask = 0x2000000U;
		printf("Starting from sector probe $%X in SDHC mode\n", mask);
	} else {
		mask = 0x200000;	// the assumption that non-SDHC card cannot be bigger than 2Gbyte
		printf("Starting from sector probe $%X in non-SDHC mode\n", mask);
	}
	size = 0;
	while (mask) {
		int r;
		printf("DETECT: trying to read sector $%X ...\n", size | mask);
		r = sd_read_sector(size | mask);
		if (r < 0) {
			fprintf(stderr, "Communication error while detecting SD-card size!\n");
			return -1;
		}
		if (r == 0)
			size |= mask;
		mask >>= 1U;
	}
	printf("Detected card size $%X (%u) max readable sector, $%X (%u) sectors in total ~ %d Mbyte\n",
		size, size, size+1, size+1,  (size+1) >> 11
	);
	com.sdsize = size + 1;
#ifdef USE_BUSE
        // LGB: according to my test, everything should be set if blksize is set, or segfault happens!
	aop.blksize = 512;
	aop.size_blocks = com.sdsize;
	aop.size = (u_int64_t)aop.blksize * (u_int64_t)aop.size_blocks;
#endif
	return 0;
}




#define PERFORMANCE_TEST_SECTORS 1000

static int cmd_sdtest ( int argc, char **argv )
{
	int sector;
	int usec;
	com.debug = 0;
	for (sector = 0; sector <= 1; sector++) {
		int r;
		printf("*** READING SECTOR %d ***\n", sector);
		r = sd_read_sector(sector);
		if (r)
			return -1;
		printf("Received SD-card status register: $%02X\n", com.sdstatus);
		if (com.sector)
			hex_dump(com.sector, 512, "READ SECTOR", 0);
		else {
			fprintf(stderr, "Bad status ($%02X), M65 SD-card controller reported error condition.\n", com.sdstatus);
			return -1;
		}
	}
	// performance test of reading
	printf("Running performance test [with reading %d sectors].\nPlease stand by ...\n", PERFORMANCE_TEST_SECTORS);
	usec = 0;
	for (sector = 0; sector < PERFORMANCE_TEST_SECTORS; sector++) {
		int r = sd_read_sector(sector);
		if (r < 0) {
			fprintf(stderr, "Error during performance test communication @ sector %d\n", sector);
			return -1;
		}
		if (!com.sector || r > 0) {
			fprintf(stderr, "Error during SD-card reading on M65 @ sector %d\n", sector);
			return -1;
		}
		usec += com.round_trip_usec;
	}
	printf("DONE.\nSectors read: %d\nTotal number of retransmissions: %d\nSeconds: %f\nSectors/second: %f\nKilobytes/second: %f\n",
		PERFORMANCE_TEST_SECTORS,
		com.retransmissions,
		usec / 1000000.0,
		PERFORMANCE_TEST_SECTORS / ((float)usec / 1000000.0),
		PERFORMANCE_TEST_SECTORS / ((float)usec / 1000000.0) * 512.0 / 1024.0
	);
	return 0;
}


static int cmd_sdsizetest ( int argc, char **argv )
{
	int r;
	if (com.sdsize != -1)
		printf("(cached result)\n");
	r = sd_get_size();
	print_sd_size();
	return r;
}


static int cmd_memdump ( int argc, char **argv )
{
	FILE *fp;
	int addr;
	unsigned char mem[0x40000];
	int usec = 0;
	for (addr = 0; addr < sizeof mem; addr += 1024) {
		int mem_index;
		msg_begin();
		mem_index = msg_add_readmem(addr, 1024);	// we transfer 1K at once. Hopefully it fits into the MTU, it should be on ethernet LAN at least ...
		if (msg_commit())
			return -1;
		memcpy(mem + addr, com.r_buf + mem_index, 1024);
		usec += com.round_trip_usec;
	}
	printf("WOW! Dump is completed, %d retransmission was needed, avg transfer rate is %f Kbytes/sec.\n", com.retransmissions,
		sizeof(mem)*1000000 / (float)usec / 1024.0
	);
	fp = fopen("mem.dmp", "wb");
	if (!fp) {
		perror("Cannot create file");
		return -1;
	}
	if (fwrite(mem, sizeof mem, 1, fp) != 1) {
		fclose(fp);
		fprintf(stderr, "Cannot write file, target can be incomplete!\n");
		return -1;
	}
	fclose(fp);
	return 0;
}


static int test_mms_and_connectivity ( void )
{
	com.mtu_size = MAX_MTU_INITIAL;	// start with not realistic one (on ethernet at least - and M65 "must be" on ethernet ...)
	com.debug = 0;
	for (;;) {
		// fool msg_commit now, we want to send, but totally invalid message ...
		printf("Trying to connect server with MMS (MTU - protocol_overhead) size %d ...\n", com.mtu_size);
		msg_begin();
		com.s_p[0] = 0;	// insert an invalid command ...
		com.s_p[1] = 3;	// close the command chain just in case ...
		com.s_p = com.s_buf + com.mtu_size - 1;
		msg_commit();
		if (com.has_answer)
			break;
		if (com.mtu_changed)
			com.header_overhead++;
		else
			sleep(1);
		/*

		int r;
		printf("Probing message with size %d ...\n", com.mtu_size);
		r = m65_send(com.s_buf, com.mtu_size);
		if (r == -1) {
			fprintf(stderr, "Test failed :-(\n");
			return -1;
		}
		sleep(1);*/
	}
	printf("MMS size discovered: %d\n", com.mtu_size);
	return 0;
}



static int cmd_test ( int argc, char **argv )
{
	time_t t = time(NULL);
	struct tm *tm_p;
	int i, ans;
	unsigned char buf[41];
	com.debug = 1;	// turn debug ON
	tm_p = localtime(&t);
	if (!tm_p) {
		perror("localtime()");
		return -1;
	}
	i = strftime((char*)(void*)buf, sizeof(buf), "%H:%M:%S", tm_p);
	if (!i) {
		perror("strftime()");
		return -1;
	}
	// We have some time ;-P
	msg_begin();	// start to construct a new message for M65
	msg_add_writemem(2016, i, buf);	// injecting the current time into the C64 screen mem!
	ans = msg_add_readmem(1024, 40);		// also, we want to see the first line of the C64 screen
	if (msg_commit())	// commit message + wait answer
		return -1;
	printf("We've read out the first line of your screen  ");
	for (i = 0; i < 40; i++) {
		char c = com.r_buf[ans++] & 0x7F;
		if (c < 32)
			c += 64;
		putchar(c);
	}
	printf("\nWell, the screen code conversion is not perfect though in this client :-)\n");
	printf("Also, we've injected the current local time on your PC to your M65 screen.\n");
	return 0;
}


static int cmd_nbd ( int argc, char **argv )
{
#ifdef USE_BUSE
	if (argc != 1) {
		fprintf(stderr, "NBD mode needs exactly one command-level parameter, NBD device, like /dev/nbd0\n");
		return 1;
	}
	nbd_debug = 1;
	if (sd_get_size()) {	// We need to run the size detection. It will fill "aop" struct as well.
		fprintf(stderr, "Size detection failed\n");
		return -1;
	}
	return buse_main(argv[0], &aop, (void *)&nbd_debug);
#else
	fprintf(stderr, "This client has not been compiled with support (Linux-only feature) for NBD!\n");
	return 1;
#endif
}


static int get_param_as_num ( const char *s )
{
	long int ret;
	char *endptr;
	if (!s || !*s) {
		fprintf(stderr, "Numeric parameter is empty or NULL\n");
		return -1;
	}
	if (s[0] == '0' && s[1] >= '0' && s[1] <= '9') {
		fprintf(stderr, "Octal notion is not supported to avoid confusion (number starts with '0' other than zero itself)\n");
		return -1;
	}
	ret = strtol(s, &endptr, 0);
	if (*endptr != '\0') {
		fprintf(stderr, "Invalid numeric parameter was specified (maybe not numeric/integer, etc)\n");
		return -1;
	}
	if (ret < 0) {
		fprintf(stderr, "Negative number was specified as numeric paramter\n");
		return -1;
	}
	return ret;
}


static int cmd_memrd ( int argc, char **argv )
{
	int addr, mem_index;
	if (!argc)
		return get_param_as_num(NULL);	// lazy way to do this ;-P
	addr = get_param_as_num(argv[0]);
	if (addr < 0)
		return -1;
	printf("ADDR = %d ~ $%X\n", addr, addr);
	msg_begin();
	mem_index = msg_add_readmem(addr, 512);
	if (msg_commit())
		return -1;
	hex_dump(com.r_buf + mem_index, 512, "memory dump", addr);
	return 0;
}

static int cmd_sdrdsect ( int argc, char **argv )
{
	int addr;
	if (!argc)
		return get_param_as_num(NULL);	// lazy way to do this ;-P
	addr = get_param_as_num(argv[0]);
	if (addr < 0)
		return -1;
	printf("SECTOR = %d ~ $%X\n", addr, addr);
	if (sd_read_sector(addr))
		return -1;
	hex_dump(com.sector, 512, "Sector dump", 0);
	return 0;
}


static int cmd_help ( int argc, char **argv );

static const struct {
	const char *cmd;
	int (*func)(int,char**);
	const char *help;
} cmd_tab[] = {
	{ "test", cmd_test, "Simple test to put clock on M65 screen, and read first line of M65 screen back" },
	{ "sdtest", cmd_sdtest, "SD-Card read-test for two sectors, and performance test on multiple reading" },
	{ "sdsize", cmd_sdsizetest, "Detect SD-card size from client (can give cached result!)" },
	{ "sdrd", cmd_sdrdsect, "Reads a given sector from SD-card (paramter is the sector number)" },
	{ "memdump", cmd_memdump, "Dumps M65's memory (first 256K) into file mem.dmp" },
	{ "memrd", cmd_memrd, "Reads the (linear) M65 memory map from given address (parameter)" },
	{ "nbd", cmd_nbd, "Creates an NBD device which can be mounted on Linux (requires device name)" },
	{ "-h", cmd_help, NULL },	// -h is here, since this is used by cmd-line as well, and "help" can be a hostname too by the non-shell syntax ...
	{"help", cmd_help, NULL },
	{ NULL, NULL, NULL }
};


static int cmd_help ( int argc, char **argv )
{
	int i, hit = 0;
	if (!argc)
		printf("Available commands:\n");
	else
		printf("Help request on command '%s':\n", argv[0]);
	for (i = 0; cmd_tab[i].cmd; i++) {
		if (cmd_tab[i].func == cmd_help)
			continue;
		if (argc && strcmp(cmd_tab[i].cmd, argv[0])) {
			continue;
		}
		printf("  %-16s%s\n", cmd_tab[i].cmd, cmd_tab[i].help ? cmd_tab[i].help : "");
		hit = 1;
	}
	if (argc && !hit)
		fprintf(stderr, "No such command '%s', cannot give help on that.\n", argv[0]);
	return 0;
}


static int m65_cmd_executor ( int argc, char **argv )
{
	int i;
	if (argc == 0) {
		fprintf(stderr, "m65_cmd_executor() with zero params!\n");
		return 1;
	}
#if 0
	i = 0;
	while (i < argc) {
		printf("Param#%d=\"%s\"\n", i, argv[i]);
		i++;
	}
#endif
	for (i = 0; cmd_tab[i].cmd; i++)
		if (!strcmp(cmd_tab[i].cmd, argv[0]))
			return cmd_tab[i].func(argc - 1, argv + 1);
	fprintf(stderr, "Unknown command: '%s'. Use help.\n", argv[0]);
	return 1;
}



static int m65_shell ( const char *hostname, int port )
{
	char prompt[80];
	sprintf(prompt, "m65@%s:%d> ", hostname, port);
	printf("*** Welcome to the M65-client shell! Press CTRL-D to exit with empty command line ***\n");
	for (;;) {
		char *args[80];
		char *line = readline(prompt);
		int i;
		if (!line)	// EOF (eg CTRL-D pressed) will gives us NULL back! This is also a sign for exit.
			break;
		if (*line)
			add_history(line);
		for (i = 0;;) {
			args[i] = strtok(i ? NULL : line, "\t ");
			if (!args[i])
				break;
			i++;
		}
		if (i && !strcmp(args[0], "exit"))
			i = -1;
		if (i > 0) {
			//add_history(line);
			m65_cmd_executor(i, args);
		}
		free(line);	// readline malloc()'s the answer for us, we must free() it
		if (i < 0)
			break;
	}
	printf("\nBy(T)e!\n");
	return 0;
}




int main ( int argc, char **argv )
{
	int port;
	if (argc > 1 && !strcmp(argv[1], "-h"))
		return m65_cmd_executor(1, argv + 1);
	if (argc < 3) {
		fprintf(stderr, "Bad usage.\n\t%s hostname portnumber [COMMAND [possible command parameters]]\n(without COMMAND the built-in shell will be used)\nFor list of command-line options, specify ONLY -h, or use help command in the shell\n", argv[0]);
		return 1;
	}
	if (strlen(argv[1]) > 64) {
		fprintf(stderr, "Too long hostname was specified.\n");
		return 1;
	}
	port = atoi(argv[2]);
	if (port <= 0 || port > 0xFFFF) {
		fprintf(stderr, "Bad port value given\n");
		return 1;
	}
	if (m65_con_init(argv[1], port)) {
		fprintf(stderr, "Network setup failed\n");
		return 1;
	}
	if (test_mms_and_connectivity())
		return 1;
	if (argc == 3)
		port = m65_shell(argv[1], port);
	else
		port = m65_cmd_executor(argc - 3, argv + 3);
	close(com.sock);
	return port;
}
