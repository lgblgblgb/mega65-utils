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


#include <string.h>
#include "m65c.h"


Uint32 sd_size;
Uint32 sd_block;

Uint8 sd_read_block ( void ) 
{
	return 0;
}

Uint8 sd_write_block ( void )
{
	return 0;
}


static void sd_init ( void )
{
}


extern void m65_sys_prepare();

void main ( void )
{
	m65_sys_prepare();	// will NOT return here!
}


