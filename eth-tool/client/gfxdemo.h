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

#ifndef _LOCAL_GFXDEMO_HACKY_HEADER_INCLUDED
#define _LOCAL_GFXDEMO_HACKY_HEADER_INCLUDED

extern unsigned char fcm_video_ram[2048];
extern unsigned char fcm_tiles[320*200];
extern unsigned char custom_palette[0x300];
extern const unsigned char some_photo[];

extern void fcm_create_video_ram ( int addr1, int addr2, int limit );
extern void gfxdemo_mand_render ( double x_center, double y_center, double zoom );
extern void create_mand_palette ( void );
extern void gfxdemo_convert_image ( const unsigned char *stripped_tga );

#endif
