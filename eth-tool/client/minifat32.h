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

#ifndef _LOCAL_MINIFAT32_HACKY_HEADER_INCLUDED
#define _LOCAL_MINIFAT32_HACKY_HEADER_INCLUDED


#define MFAT32_DIR	0x10


struct mfat32_dir_entry {
	char	name[9], ext[4];
	char	full_name[8+3+1+1];
	int	cluster;
	int	size;
	int	type;
};

extern int mfat32_mount ( 
	int (*reader_callback)(unsigned int, unsigned char*),
	int (*writer_callback)(unsigned int, unsigned char*),
	unsigned int set_starting_sector,
	unsigned int set_partition_size
);
extern int mfat32_dir_get_next_entry ( struct mfat32_dir_entry *entry, int first );
extern int mfat32_dir_find_file ( const char *filename, struct mfat32_dir_entry *entry );
extern int mfat32_download_file ( const char *fat_filename, const char *host_filename );
extern int mfat32_chdir ( const char *dirname );
extern void mfat32_chroot ( void );

#endif
