/*
	** A work-in-progess Mega-65 (Commodore-65 clone origins) emulator
	** Part of the Xemu project, please visit: https://github.com/lgblgblgb/xemu
	** Copyright (C)2018 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>

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


#define MAX_MTU	1400
#define RETRANSMIT_TIMEOUT_USEC	500000
#define M65_IO_ADDR(a)    (((a)&0xFFF)|0xFFD3000)
#define SD_STATUS_SDHC_FLAG 0x10
#define SD_STATUS_ERROR_MASK (0x40|0x20)

static struct {
	int mtu_size;
	int sock;
	int in_progress_msg;
	unsigned char s_buf[MAX_MTU], *s_p;
	unsigned char r_buf[MAX_MTU];
	int s_size, r_size, ans_size_expected, m65_size;
	int round_trip_usec;
	int retransmissions;
	int retransmit_timeout_usec;
	int sdhc;
	int sdsize;
	int sdstatus;
	unsigned char *sector;
	int debug;
} com;



#ifdef USE_BUSE
static int sd_read_sector ( unsigned int sector );

static int nbd_debug;

static int nbd_op_read(void *buf, u_int32_t len, u_int64_t offset, void *userdata)
{
	if (*(int *)userdata)
		fprintf(stderr, "R - %lu, %u\n", offset, len);
	// WARNING IT'S MAYBE NOT WORKS (DENYING UNALIGNED ACCESS)
	if ((len & 511)) {
		fprintf(stderr, "NBD: ERROR: Length is not multiple of 512\n");
		return -1;
	}
	if ((offset & 511UL)) {
		fprintf(stderr, "NBD: ERROR: Offset is not 512-byte aligned\n");
		return -1;
	}
	len >>= 9;
	offset >>= 9;
	while (len--) {
		if (sd_read_sector(offset++))
			return -1;
		memcpy(buf, com.sector, 512);
		buf += 512;
	}
	return 0;
/*

	if (*(int *)userdata)
		fprintf(stderr, "R - %lu, %u\n", offset, len);
	memcpy(buf, (char *)data + offset, len);*/
	return 0;
}

static int nbd_op_write(const void *buf, u_int32_t len, u_int64_t offset, void *userdata)
{
	if (*(int *)userdata)
		fprintf(stderr, "W - %lu, %u\n", offset, len);
	return -1;
/*	memcpy((char *)data + offset, buf, len);
	return 0;*/
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
	.blksize = 512,
	.size_blocks = 512 * 1024,
	.size = 512*512*1024
};
#endif





static int m65_send ( void *buffer, int len )
{
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
				// query MTU after an EMSGSIZE error
				pl = sizeof(com.mtu_size);
				if (getsockopt(com.sock, IPPROTO_IP, IP_MTU, &com.mtu_size, &pl) == -1) {
					perror("SEND: getsockopt(IPPROTO_IP, IP_MTU)");
					return -1;
				}
				printf("SEND: note: MTU is %d bytes\n", com.mtu_size);
				continue;	// try again!
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
	com.mtu_size = MAX_MTU;	// some value ...
	com.retransmissions = 0;
	com.retransmit_timeout_usec = RETRANSMIT_TIMEOUT_USEC;
	com.sdhc = -1;
	com.sdsize = -1;
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


static void hex_dump ( unsigned const char *buffer, int size, const char *comment )
{
	int i = 0;
	printf("DUMP[%s; %d bytes]:\n", comment, size);
	while (i < size) {
		if (!(i & 15)) {
			if (i)
				putchar('\n');
			printf("  %04X  ", i);
		}
		printf(" %02X", buffer[i]);
		i++;
	}
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
		hex_dump(com.s_buf, com.s_size, "REQUEST TO SEND");
	gettimeofday(&tv1, NULL);
	com.in_progress_msg = 0;

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
	if (com.debug)
		hex_dump(com.r_buf, com.r_size, "RECEIVED ANSWER");
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


static int sd_read_sector ( unsigned int sector )
{
	unsigned char buffer[6];
	int sd_status_index, sd_data_index;
	com.sector = NULL;
	// sets com.sdhc, if it wasn't before
	if (sd_get_sdhc())
		return -1;
	// We always want to use plain sector addressing.
	// So, we check SDHC bit of status, and if it is not set,
	// we convert "sector" to byte addressing here. The caller
	// of this function doesn't need to know anoything this
	if (!com.sdhc) {
		if (sector >= 0x800000) {
			fprintf(stderr, "Reading sector %X would result in invalid byte offset in non-SDHC mode!\n", sector);
			return -1;
		}
		sector <<= 9U;
	}
	buffer[0] = sector & 0xFF;
	buffer[1] = (sector >> 8) & 0xFF;
	buffer[2] = (sector >> 16) & 0xFF;
	buffer[3] = (sector >> 24) & 0xFF;
	buffer[4] = 2;		// read block command for M65 SD controller
	//buffer[5] = 1;		// end reset??????
	msg_begin();
	//msg_add_writemem(M65_IO_ADDR(0xD680), 1, buffer + 5);	// end reset???
	msg_add_writemem(M65_IO_ADDR(0xD681), 4, buffer);
	msg_add_writemem(M65_IO_ADDR(0xD680), 1, buffer + 4);
	sd_status_index = msg_add_waitsd();
	// we want to read the SD-card buffer now (even there is an error - see status -, then we don't use it, but better than using TWO messages/transmission rounds ...)
	sd_data_index = msg_add_readmem(0xFFD6E00, 512);
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


static int sd_get_size ( void )
{
	unsigned int mask, size;
	if (com.sdsize != -1)
		return com.sdsize;	// cached value, if any
	printf("Detecting card size is in progress ...\n");
	// Reading sector zero is for just getting SDHC flag, and also initial test, that we can read at all!
	printf("Reading sector 0 for testing ...\n");
	if (sd_read_sector(0))
		return -1;
	if (com.sdhc) {
		//mask = 0x80000000U;
		mask = 0x2000000U;
	} else {
		mask = 0x200000;
		printf("Starting from non-SDHC max\n");
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

static int cli_sdtest ( void )
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
			hex_dump(com.sector, 512, "READ SECTOR");
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


static int cli_sdsizetest ( void )
{
	return sd_get_size();
}


static int cli_memdump ( void )
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


static int cli_memtest ( void )
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


static int cli_nbd ( const char *device )
{
	nbd_debug = 1;
	if (sd_get_size()) {	// We need to run the size detection. It will fill "aop" struct as well.
		fprintf(stderr, "Size detection failed\n");
		return -1;
	}
	return buse_main(device, &aop, (void *)&nbd_debug);
}




int main ( int argc, char **argv )
{
	int r;
	if (argc < 4) {
		fprintf(stderr, "Bad usage: %s hostname portnumber COMMAND [possible command parameters]\n", argv[0]);
		return 1;
	}
	if (m65_con_init(argv[1], atoi(argv[2]))) {
		fprintf(stderr, "Network setup failed\n");
		return 1;
	}
	printf("Entering into communication state.\n");
	if (!strcmp(argv[3], "test"))
		r = cli_memtest();
	else if (!strcmp(argv[3], "sdtest"))
		r = cli_sdtest();
	else if (!strcmp(argv[3], "sdsizetest"))
		r = cli_sdsizetest();
	else if (!strcmp(argv[3], "memdump"))
		r = cli_memdump();
	else if (!strcmp(argv[3], "nbd")) {
		if (argc != 5) {
			fprintf(stderr, "NBD mode needs exactly one command-level parameter, NBD device, like /dev/nbd0\n");
			r = 1;
		} else
			r = cli_nbd(argv[4]);
	} else {
		fprintf(stderr, "Unknown command \"%s\"\n", argv[3]);
		r = 1;
	}
	close(com.sock);
	return r ? 1 : 0;
}
