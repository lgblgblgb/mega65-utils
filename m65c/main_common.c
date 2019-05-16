/*  Some file-commander like study for Mega65 computer.
  
    Copyright (C)2019 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>

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


#include "m65c.h"
#include <string.h>

void clear_screen ( void )
{
	memset(vram, 0x20, 2000);
	memset(cram,    1, 2000);
	/*
	Uint16 a;
	for (a = 0; a < 2000; a++) {
		vram[a] = 0x20;
		cram[a] = 1;
	}*/
}

static const char panic_msg[] = " *** PANIC. SPACE to exit. Msg:";

#ifdef MEGA65
extern Uint16 ethernet_poll ( void );
#endif


void PANIC ( const char *msg )
{
	SET_BGCOL(0);
	memset(vram, 0x20, 160);
	memset(cram,   13, 160);
	memcpy(vram, panic_msg, strlen(panic_msg));
	memcpy(vram + 81, msg, strlen(msg));
	while (sys_waitkey() != 0x20);
	EXIT(1);
}



static const char title[] = "Press keys for a while (do not overflow the screen please). Press q to exit.";


#ifdef MEGA65

static const Uint8 hexdigits[] = "0123456789ABCDEF";


void show_eth_buffer ( void )
{
	Uint8 *s = vram + 160;
	int a;
	vram[80] = hexdigits[PEEK(0x2FF) >> 4];
	vram[81] = hexdigits[PEEK(0x2FF) & 15];
	vram[82] = hexdigits[PEEK(0x2FE) >> 4];
	vram[83] = hexdigits[PEEK(0x2FE) & 15];

	for (a = 0; a < 6; a++) {
		Uint8 c = PEEK(0xD6E9 + (unsigned int)a);
		vram[100 + a * 2] = hexdigits[c >> 4];
		vram[101 + a * 2] = hexdigits[c & 15];
	}
	for (a = 0; a < 400; a++) {
		Uint8 c = eth_buffer[a];
		s[0] = hexdigits[c >> 4];
		s[1] = hexdigits[c & 15];
		s += 4;
	}
}
#endif



// This is our real "main" function. It MUST NOT RETURN ever, or bad things happen at least on CC65!
// Use PANIC() to exit with a panic msg, or EXIT() to simply exit.
void main_common ( void )
{
	Uint16 a;
	SET_BGCOL(6);
	SET_BDCOL(6);
	clear_screen();
	memcpy(vram, title, strlen(title));
	a = 80;
	for (;;) {
#ifdef MEGA65
		ethernet_poll();
		//show_eth_buffer();
#else
		Uint8 k = sys_waitkey();
		if (k == 'q') {
			//EXIT(0);
			PANIC("Exit magic key is pressed, this is a test panic message ;-P");
		}
		vram[a] = k;
		a++;
#endif
	}
}

