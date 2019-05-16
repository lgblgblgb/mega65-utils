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

#ifndef _M65C_M65C_H
#define _M65C_M65C_H

// As we want to use ASCII representation of characters even on Mega65 (with own charset)
// we instruct CC65 not to convert string literals to PETSCII. The include file does that.
// Note, it's safe to include here, native build will ignore it because of the #ifdef __C65__
// in it. This also means, that m65c.h should be the first thing to include in our C sources,
// but it's also applies because of some type definitions etc here.
#include "cc65_ascii_mapping.h"

#ifdef __CC65__

/************************
 * MEGA65 SPECIFIC PART *
 ************************/

#define MEGA65

// Define about the same types, what SDL also uses (for native build) so we have some kind of
// similar situation for M65 and native build as well.
typedef unsigned char Uint8;
typedef signed char Sint8;
typedef unsigned int Uint16;
typedef signed int Sint16;
typedef unsigned long int Uint32;
typedef signed long int Sint32;
// you should NOT change these, at assembly level there are the corresponding config in asm_m65.a65!
#define vram ((Uint8*)0xF000)
#define cram ((Uint8*)0xD800)

#define POKE(a,d) *(Uint8*)(a) = (d)
#define PEEK(a) (*(Uint8*)(a))
//#define SET_BGCOL(n) *(Uint8*)(0xD021) = (n)
#define SET_BDCOL(n) POKE(0xD020, n)
#define SET_BGCOL(n) POKE(0xD021, n)
#define check_events()
#define DEBUG(...)

// As we use our own screen memory at the end of the CPU's 64K view, and we don't use any KERNAL/BASIC
// whatever feature either, basically we have free memory between addresses 512 and 2048. We want to
// use those areas for something useful. Namely, SD-card buffer and ethernet buffer (NOTE: we don't
// need too larger ethernet buffer, as we handle only UDP with our own protocol, and some easy ones
// like DHCP, ARP, TFTP ..., so 3*256 bytes sounds reasonable).
// NOTE: we must have two bytes free BEFORE eth_buffer, that will hold the eth RX size!!!!
// Do not change these, it must be in sync with asm_m65.a65 !
#define sd_buffer ((Uint8*)0x600)
#define eth_buffer ((Uint8*)0x300)

#define sys_checkkey()	PEEK(0xD610)

#else
/************************
 * NATIVE SPECIFIC PART *
 ************************/
#define NATIVE
#ifdef __WIN32
#	define WINDOWS
#else
#	define UNIX
	/* Windows needs O_BINARY ... So we use that too, in case of UNIX, we simply define it to zero, so it does make problems ... */
#	define O_BINARY 0
#endif

#include <SDL_stdinc.h>
extern Uint8 bgcol;
extern Uint8 vram[];
extern Uint8 cram[];
#define SET_BGCOL(n) bgcol = (n)
#define SET_BDCOL(n)
void check_events ( void );
#define DEBUG(...) printf(__VA_ARGS__)
extern Uint8 sd_buffer[];

extern Uint8 sys_checkkey ( void );

#endif

/**********************
 * COMMON/SHARED PART *
 **********************/

extern void   EXIT ( Uint8 retval );

extern Uint8  sd_read_block  ( void );
extern Uint8  sd_write_block ( void );
extern Uint32 sd_size;
extern Uint32 sd_block;

extern Uint8 sys_getkey ( void );
extern Uint8 sys_waitkey ( void );


#endif
