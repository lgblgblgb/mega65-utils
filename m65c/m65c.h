#ifndef _M65C_M65C_H
#define _M65C_M65C_H

#include "cc65_ascii_mapping.h"

#ifdef __CC65__
#define MEGA65

typedef unsigned char Uint8;
typedef signed char Sint8;
typedef unsigned int Uint16;
typedef signed int Sint16;
typedef unsigned long int Uint32;
typedef signed long int Sint32;
#define vram ((Uint8*)0xF000)
#define cram ((Uint8*)0xD800)
#define POKE(a,d) *(Uint8*)(a) = (d)
#define PEEK(a) (*(Uint8*)(a))
//#define SET_BGCOL(n) *(Uint8*)(0xD021) = (n)
#define SET_BDCOL(n) POKE(0xD020, n)
#define SET_BGCOL(n) POKE(0xD021, n)
#define check_events()
#define DEBUG(...)

#define sys_checkkey()	PEEK(0xD610)


#else
#define UNIX

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

// Common functions

extern void   m65c_exit ( Uint8 retval );

extern Uint8  sd_read_block  ( void );
extern Uint8  sd_write_block ( void );
extern Uint32 sd_size;
extern Uint32 sd_block;

extern Uint8 sys_getkey ( void );
extern Uint8 sys_waitkey ( void );


#endif
