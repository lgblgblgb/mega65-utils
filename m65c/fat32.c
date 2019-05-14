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


/* Ugly FAT32 implementation tries ... */
#include "m65c.h"


struct fat32_file_st {
	Uint32	dir_base_cluster;
	Uint32	dir_entry_cluster;
	Uint16	dir_entry_offset;
	Uint32	start_cluster;
	Uint32	current_cluster;
	Uint8	current_sector;
	Uint32	file_pos;
	Uint32	file_size;
};



Uint32 read_next_cluster ( Uint32 cluster_now )
{

}



void fat32_set_partition ( Uint8 partnum )
{
	sd_block = 0;
	sd_read_block();
}




void fat32_test ( void )
{
	sd_block = 0;
	sd_read_block();
}


