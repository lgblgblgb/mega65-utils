/*
	** A work-in-progess Mega-65 (Commodore-65 clone origins) emulator
	** Part of the Xemu project, please visit: https://github.com/lgblgblgb/xemu
	** Copyright (C)2018 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>

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


#define MAX_MTU	1400


static struct {
	int mtu_size;
	int sock;
	unsigned char s_buf[MAX_MTU], *s_p;
	unsigned char r_buf[MAX_MTU];
	int s_size, r_size, ans_size_expected, m65_size;
} conn;



static int m65_send ( void *buffer, int len )
{
	for (;;) {
		int ret;
		socklen_t pl;
		if (len > conn.mtu_size) {
			fprintf(stderr, "SEND: Too long message (%d), over PMTU (%d)\n", len, conn.mtu_size);
			return -1;
		}
		//pl = sizeof(conn.serveraddr);
		ret = send(
			conn.sock,
			buffer,
			len,
			0//,
			//(struct sockaddr *)&conn.serveraddr,
			//sizeof(conn.serveraddr)
		);
		if (ret == -1) {
			if (errno == EMSGSIZE) {
				// query MTU after an EMSGSIZE error
				pl = sizeof(conn.mtu_size);
				if (getsockopt(conn.sock, IPPROTO_IP, IP_MTU, &conn.mtu_size, &pl) == -1) {
					perror("SEND: getsockopt(IPPROTO_IP, IP_MTU)");
					return -1;
				}
				printf("SEND: note: MTU is %d bytes\n", conn.mtu_size);
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
	conn.sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (conn.sock < 0) {
		perror("Opening socket");
		return -1;
	}
	server = gethostbyname(hostname);
	if (!server) {
		fprintf(stderr,"Cannot resolve name '%s' or other error: %s\n", hostname, hstrerror(h_errno));
		close(conn.sock);
		return -1;
	}
	conn.mtu_size = MAX_MTU;	// some value ...
	printf("Sending to server: (%s) %u.%u.%u.%u:%d with initial MTU of %d bytes ...\n",
		hostname,
		server->h_addr[0] & 0xFF,
		server->h_addr[1] & 0xFF,
		server->h_addr[2] & 0xFF,
		server->h_addr[3] & 0xFF,
		port,
		conn.mtu_size
	);
	memset(&serveraddr, 0, sizeof(serveraddr));
	serveraddr.sin_family = AF_INET;
	memcpy(&serveraddr.sin_addr.s_addr, server->h_addr, server->h_length);
	serveraddr.sin_port = htons(port);
	// Actually not a "connect" in case of UDP, just to save specify parameters all the
	// the time at sendto() so we can use send() as well.
	if (connect(conn.sock, (struct sockaddr *)&serveraddr, sizeof(serveraddr))) {
		perror("connect()");
		close(conn.sock);
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
	if (setsockopt(conn.sock, IPPROTO_IP, IP_MTU_DISCOVER, &val, sizeof(val)) == -1) {
		perror("setsockopt(sock, IPPROTO_IP, IP_MTU_DISCOVER)");
		close(conn.sock);
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


// Start to construct a new monitor port request
static void msg_begin ( void )
{
	conn.s_buf[0] = 0;
	conn.s_buf[1] = 'M';
	conn.s_buf[2] = '6';
	conn.s_buf[3] = '5';
	conn.s_buf[4] = '*';
	conn.s_p = conn.s_buf + 5;
	conn.ans_size_expected = 8;	// expected base size is 8:  marker=5 + size=2 + status=1
}

static int msg_add_readmem ( int m65_addr, int size )
{
	int expected_answer_pos;
	expected_answer_pos = conn.ans_size_expected;
	conn.ans_size_expected += size;		// answer should contain these amount of bytes!
	*conn.s_p++ = 1;			// command code: read memory
	*conn.s_p++ = size & 0xFF;		// length low byte
	*conn.s_p++ = size >> 8;		// length hi byte
	*conn.s_p++ = m65_addr & 0xFF;		// 4 byte of M65 address
	*conn.s_p++ = (m65_addr >> 8) & 0xFF;
	*conn.s_p++ = (m65_addr >> 16) & 0xFF;
	*conn.s_p++ = (m65_addr >> 24) & 0x0F;	// only 28 bits on M65
	return expected_answer_pos;
}

static void msg_add_writemem ( int m65_addr, int size, unsigned char *buffer )
{
	// write does not extend the answer size at all!
	*conn.s_p++ = 2;			// command code: write memory
	*conn.s_p++ = size & 0xFF;		// length low byte
	*conn.s_p++ = size >> 8;		// length hi byte
	*conn.s_p++ = m65_addr & 0xFF;		// 4 byte of M65 address
	*conn.s_p++ = (m65_addr >> 8) & 0xFF;
	*conn.s_p++ = (m65_addr >> 16) & 0xFF;
	*conn.s_p++ = (m65_addr >> 24) & 0x0F;	// only 28 bits on M65
	// Now also add the data as well to be written on the M65 size
	// dangerous: zero should be currently NOT used!
	memcpy(conn.s_p, buffer, size);
	conn.s_p += size;
}

static int msg_commit ( int debug )
{
	*conn.s_p++ = 3;	// close the list of commands!!!!!
	conn.s_size = conn.s_p - conn.s_buf;	// calculate our request's total size
	if (debug)
		hex_dump(conn.s_buf, conn.s_size, "REQUEST TO SEND");
	// SEND. FIXME: maybe we should use select() and non blocking I/O to detect OS problem(s) on sending?
	if (m65_send(conn.s_buf, conn.s_size) <= 0) {
		fprintf(stderr, "m65_send() returned with error :-(\n");
		return -1;
	}
	// Receive answer.
	// Note: monitor MUST always receive. We can't send newer if it's not the case!
	// We should re-transmit our request on some certain timeout, TODO FIXME
	conn.r_size = recv(conn.sock, conn.r_buf, conn.mtu_size, 0);
	if (conn.r_size < 0) {
		perror("recv()");
		return -1;
	}
	if (conn.r_size == 0) {
		fprintf(stderr, "recv() returned with zero size!\n");
		return -1;
	}
	if (debug)
		hex_dump(conn.r_buf, conn.r_size, "RECEIVED ANSWER");
	if (conn.r_size < 8) {
		fprintf(stderr, "Abnormally short answer, at least 8 bytes, we got %d\n", conn.r_size);
		return -1;
	}
	if (conn.r_buf[0] || conn.r_buf[1] != 'M' || conn.r_buf[2] != '6' || conn.r_buf[3] != '5' || conn.r_buf[4] != '*') {
		fprintf(stderr, "Magic marker cannot be found in the answer!\n");
		return -1;
	}
	conn.m65_size = conn.r_buf[5] + (conn.r_buf[6] << 8);
	if (conn.m65_size != conn.r_size) {
		fprintf(stderr, "Internal mismtach, received size (%d) is not the same what the answer states (%d) to be\n", conn.r_size, conn.m65_size);
		return -1;
	}
	if (conn.r_size != conn.ans_size_expected) {
		fprintf(stderr, "answer size mismatch, got %d bytes, request expected %d bytes as answer\n", conn.r_size, conn.ans_size_expected);
		return -1;
	}
	if (conn.r_buf[7]) {
		fprintf(stderr, "M65 reports error, error code = $%02X\n", conn.r_buf[7]);
		return -1;
	}
	if (debug)
		printf("WOW, answer seems to be OK ;-)\n");
	return 0;
}







static int test ( void )
{
	time_t t = time(NULL);
	struct tm *tm_p;
	int i, ans;
	unsigned char buf[41];
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
	msg_commit(1);	// commit with debug
	printf("We've read out the first line of your screen  ");
	for (i = 0; i < 40; i++) {
		char c = conn.r_buf[ans++] & 0x7F;
		if (c < 32)
			c += 64;
		putchar(c);
	}
	printf("\nWell, the screen code conversion is not perfect though in this client :-)\n");
	printf("Also, we've injected the current local time on your PC to your M65 screen.\n");
	return 0;
}



int main ( int argc, char **argv )
{
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
		test();
	else
		fprintf(stderr, "Unknown command \"%s\"\n", argv[3]);
	close(conn.sock);
	return 0;
}
