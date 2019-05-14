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

void PANIC ( const char *msg )
{
	SET_BGCOL(0);
	memset(vram, 0x20, 160);
	memset(cram,   13, 160);
	memcpy(vram, panic_msg, strlen(panic_msg));
	memcpy(vram + 81, msg, strlen(msg));
	while (sys_waitkey() != 0x20)
		;
	m65c_exit(1);
}



static const char title[] = "Press keys for a while (do not overflow the screen please). Press q to exit.";



// This is our real "main" function. It MUST NOT RETURN ever, or bad things happen at least on CC65!
// Use PANIC() to exit with a panic msg, or m65c_exit() to simply exit.
void main_common ( void )
{
	Uint16 a;
	SET_BGCOL(6);
	SET_BDCOL(6);
	clear_screen();
	memcpy(vram, title, strlen(title));
	a = 80;
	for (;;) {
		Uint8 k = sys_waitkey();
		if (k == 'q') {
			//m65c_exit(0);
			PANIC("Exit magic key is pressed, this is a test panic message ;-P");
		}
		vram[a] = k;
		a++;
	}
}

