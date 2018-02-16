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

/* This is an extremely stupid FAT32-only solution without LFN support too much. */


#include <stdio.h>
#include <string.h>
#include "minifat32.h"


static struct {
	int valid;	// valid FS signal
	int part_start; // absolute sector number for the partition itself, ie the "FS"
	int part_size;
	int fat_start;	// absolute sector number for the first FAT
	int fat2_start;	// start of FAT#2
	int fat_size;	// fat size in sectors
	int fs_start;	// ie, absolute sector number of cluster#2
	int total_clusters;
	int cluster_size;	// cluster size in sectors
	int in_cluster_index;	// position within the cluster (ie by meaning of sector number within the cluster only!): special value -1: NOT initialized yet!
	int current_cluster;	// current cluster of current object (in_cluster_index is "inside" the cluster then)
	unsigned char fat_cache[512];	// caches 512 bytes of the FAT (ie for 512/4 = 128 clusters)
	int fat_cached_sector;		// sector number of the cached FAT sector
	unsigned char dir_cache[512];
	int dir_pointer;		// offset pointer in dir_cache for directory functions
	int root_directory;		// cluster number of root directory, usually this is 2.
	int current_directory;		// cluster of current directory
	int (*write_sector)(unsigned int, unsigned char*);
	int (*read_sector)(unsigned int, unsigned char*);
} fs = {
	.valid = 0,
	.part_start = -1,
	.part_size = -1
};

static int dir_end;


// gets the chain (ie "next" cluster) for a given cluster.
// Reads the FAT, also using the FAT cache.
// Returns a valid cluster number on the volume, of ZERO to signal end of chain
// All invalid references translated to zero! See the comments within this func
// to get to know why, but it seems to be the standard, we must do!
// return value: positive integer = OK, chained cluster
//               zero: OK, but end of chain detected
//               negative (-1): I/O error, or other serious structural problem, bad call, invalid cluster as input, etc ...
static int fat_get_chain ( int cluster )
{
	int sector, offset;
	if (cluster < 2 || cluster >= fs.total_clusters) {
		fprintf(stderr, "FAT32: invalid cluster (%d) wanted to be looked up in FAT!\n", cluster);
		return -1;
	}
	// calculate the sector number where the info is (inside the FAT)
	sector = cluster >> 7;	// one 512 byte length sector can hold 512/4=128 cluster pointers
	offset = (cluster & 127) << 2;
	sector += fs.fat_start;	// get a real sector number on the media
	if (sector != fs.fat_cached_sector) {
		// no cached, we must to read sector
		fs.fat_cached_sector = -1;	// invalidate cache, just for catching problems when read faults ...
		if (fs.read_sector(sector, fs.fat_cache)) {
			// error reading! invalidate cache ASAP!
			fs.fat_cached_sector = -1;
			fprintf(stderr, "FAT32: I/O error from callback while trying to read corresponding FAT sector\n");
			return -1;
		}
		fs.fat_cached_sector = sector;	// set cached sector indicator, do not forget this!
	}
	// get our pointer actually it's 28 bit only (FAT28 is a better name ...)! According to FAT32 specification,
	// the M.S. hex digit must be masked out before checking the result, so that & 0x0F part you see (it's also great that integer 32 bit usually won't be too small for us):
	offset = fs.fat_cache[offset] | (fs.fat_cache[offset + 1] << 8) | (fs.fat_cache[offset + 2] << 16) | ((fs.fat_cache[offset + 3] & 0x0F) << 24);
	// Now the hard part (according the spec again):
	// $?0000000,$?0000001: if occures in chains (should not), must be treated as end-of-chain
	// $?0000002-$?FFFFFEF: valid data clusters _HOWEVER_ if it's over the max clusters of the FS, it "should be" treated as end-of-chain marker again ...
	// $?FFFFFF0-$?FFFFFF7: various mystical stuffs on some DOS versions/other OSes, it seems "should be" treated as end-of-chain marker again ...
	// $?FFFFFF8-$?FFFFFF8: the "real" end of chain marker
	// To summarize: we must not use the upport 4 bits (already done above), we must take care values >=2 and <= max_clusters, the others are "end-of-chain"
	return offset >= 2 && offset < fs.total_clusters ? offset : 0;
}


static const unsigned char fat32_id[] = {'F','A','T','3','2',' ',' ',' '};



int mfat32_mount ( 
	int (*reader_callback)(unsigned int, unsigned char*),
	int (*writer_callback)(unsigned int, unsigned char*),
	unsigned int set_starting_sector,
	unsigned int set_partition_size
) {
	unsigned int total_size;
	int logical_sector_size;
	unsigned char boot[512];

	if (fs.part_start == set_starting_sector && fs.part_size == set_partition_size && fs.part_start != -1) {
		printf("Filesystem has been already in use [OK], boot record @ %d [%d sectors long]\n", set_starting_sector, set_partition_size);
		return 0;
	}

	fs.valid = 0;	// starting as invalid, before using ...
	if (set_partition_size < 2048) {
		fprintf(stderr, "FAT32: Too small partition.\n");
		goto error;
	}


	fs.read_sector = reader_callback;
	fs.write_sector = writer_callback;
	fs.part_start = set_starting_sector;
	fs.part_size = set_partition_size;
	if (fs.read_sector(fs.part_start, boot)) {
		fprintf(stderr, "FAT32: cannot read boot sector\n");
		goto error;
	}
	if (memcmp(boot + 0x52, fat32_id, sizeof fat32_id)) {
		fprintf(stderr, "FAT32: file system id \"%s\" cannot be found. Maybe not a FAT32 volume.\n", fat32_id);
		goto error;
	}
	if (boot[0x10] != 2) {
		fprintf(stderr, "FAT32: this driver only supports two FAT copies exactly, but here: %d\n", boot[0x10]);
		goto error;
	}
	logical_sector_size = boot[0xB] | (boot[0xC] << 8);
	if (logical_sector_size < 512 || (logical_sector_size & 511)) {
		fprintf(stderr, "FAT32: this driver supports only 512 bytes (or a multiple of it) per logical sector, not %d\n", logical_sector_size);
		goto error;
	}
	logical_sector_size /= 512;	// get the 512 bytes size of the logical sector
	fs.fat_size = (boot[0x24] | (boot[0x25] << 8) | (boot[0x26] << 16) | (boot[0x27] << 24)) * logical_sector_size;
	fs.root_directory = boot[0x2C] | (boot[0x2D] << 8) | (boot[0x2E] << 16) | (boot[0x2F] << 24);	// cluster of root directory
	fs.cluster_size = boot[0xD] * logical_sector_size;
	fs.fat_start = (boot[0xE] | (boot[0xF] << 8)) * logical_sector_size + fs.part_start;	// reserved logical sectors, then FAT, so get the size from it
	fs.fat2_start = fs.fat_start + fs.fat_size;
	fs.fs_start = fs.fat2_start + fs.fat_size;
	total_size = boot[0x13] | (boot[0x14] << 8);	// total logical sectors
	if (!total_size)	// if WORD entry at 0x13 is zero, use the dword entry at 0x20
		total_size = boot[0x20] | (boot[0x21] << 8) | (boot[0x22] << 16) | (boot[0x23] << 24);
	total_size *= logical_sector_size;	// get the total size in real sectors
	total_size -= fs.fs_start;		// this amount of sectors before the FS area
	fs.total_clusters = total_size / fs.cluster_size - 2;
	//printf("Total clusters: %d\n", fs.total_clusters);
	//printf("Cluster size: %d\n", fs.cluster_size);
	//printf("Logical sector size: %d\n", logical_sector_size);
	// **** Seems to be valid, set some things for initial values
	fs.valid = 1;
	fs.fat_cached_sector = -1;
	fs.current_cluster = -1;
	fs.current_directory = fs.root_directory;
	fs.in_cluster_index = -1;
	printf("Filesystem has just been put into use, boot record @ %d [%d sectors long]\n", set_starting_sector, set_partition_size);
	return 0;
error:
	fs.part_start = -1;
	fs.part_size = -1;
	return -1;
}


// Opens an object (ie, file or directory)
static void open_object ( int cluster )
{
	fs.current_cluster = cluster;
	fs.in_cluster_index = -1;	// uninitialized! (so read_next_sector will handle that)
}


// Read next sector of the open'ed object.
// Takes care about cluster-boundary step, FAT lookup then, etc etc
// Should be called directly after open_object() too, for the _first_ sector to get
// Return values:
// 0 = OK, buffer is valid
// 1 = end-of-chain situation, buffer is NOT valid
// negative = I/O error on sector reading etc
static int read_next_sector ( void *buffer )
{
	if (!fs.current_cluster)
		return 1;	// end of chain situation already.
	if (fs.in_cluster_index < fs.cluster_size - 1)
		fs.in_cluster_index++;	// this also includes the case, when in_cluster_index is -1, so no sector has been read yet
	else {
		// otherwise, we need to "step" for the next cluster!
		int chained_cluster = fat_get_chain(fs.current_cluster);
		if (chained_cluster < 0)
			return -1;	// some I/O or major FAT structure problem
		fs.current_cluster = chained_cluster;
		fs.in_cluster_index = 0;
		if (chained_cluster == 0)
			return 1;	// end-of-chain situation
	}
	// Calculate current absolute sector, and read it!
	if (fs.current_cluster < 2 || fs.current_cluster > fs.total_clusters) {
		fprintf(stderr, "FAT32: invalid cluster (%d) for read_next_sector() ...\n", fs.current_cluster);
		return -1;
	}
	return fs.read_sector((fs.current_cluster - 2) * fs.cluster_size + fs.fs_start + fs.in_cluster_index, buffer);
}


static void name_copy ( char *dst, const unsigned char *src, int len )
{
	memcpy(dst, src, len);
	do {
		dst[len--] = 0;
	} while (len >= 0 && dst[len] == 32);
}



#define DIRENTRY(n) fs.dir_cache[fs.dir_pointer+(n)]


int mfat32_dir_get_next_entry ( struct mfat32_dir_entry *entry, int first )
{
	if (first) {
		open_object(fs.current_directory);
		fs.dir_pointer = 480;	// force re-read with over sector size pointer
		dir_end = 0;
	}
	if (dir_end) {
		fprintf(stderr, "FAT32: calling mfat32_dir_findnext() when directory is over\n");
		return -1;
	}
	for (;;) {
		if (fs.dir_pointer < 480)
			fs.dir_pointer += 32;
		else {
			int ret = read_next_sector(fs.dir_cache);
			if (ret) {
				dir_end = 1;
				return ret;
			}
			fs.dir_pointer = 0;
		}
		if (DIRENTRY(0) == 0) {
			dir_end = 1;
			return 1;	// end of directory
		}
		if (DIRENTRY(0) < 0x20 || DIRENTRY(0) > 127)	// this probably should be refined ... [including the $E5 deleted entry stuff]
			continue;
		entry->type = DIRENTRY(0xB);
		if ((entry->type & 0x0F) == 0x0F)	// this is maybe an LFN-piece, not yet supported
			continue;
		if ((entry->type & 8) || (entry->type & 2))	// hidden or volume label
			continue;
		name_copy(entry->name, fs.dir_cache + fs.dir_pointer, 8);
		name_copy(entry->ext,  fs.dir_cache + fs.dir_pointer + 8, 3);
		if (!entry->name[0])
			continue;
		strcpy(entry->full_name, entry->name);
		if (entry->ext[0]) {
			strcat(entry->full_name, ".");
			strcat(entry->full_name, entry->ext);
		}
		entry->cluster = DIRENTRY(0x1A) | (DIRENTRY(0x1B) << 8) | (DIRENTRY(0x14) << 16) | ((DIRENTRY(0x15) & 0x0F) << 24);
		entry->size = DIRENTRY(0x1C) | (DIRENTRY(0x1D) << 8) | (DIRENTRY(0x1E) << 16) | (DIRENTRY(0x1F) << 24);
		return 0;
	}
}



int mfat32_dir_find_file ( const char *filename, struct mfat32_dir_entry *entry )
{
	int first = 1, ret;
	for (;;) {
		ret = mfat32_dir_get_next_entry(entry, first);
		first = 0;
		if (ret)
			return ret;	// not found, because end of directory hit, and no hit yet
		if (!strcasecmp(entry->full_name, filename))
			return 0;	// found, yeah :-)
	}
}


int mfat32_chdir ( const char *dirname )
{
	struct mfat32_dir_entry entry;
	if (mfat32_dir_find_file(dirname, &entry)) {
		fprintf(stderr, "Directory named \"%s\" cannot be found.\n", dirname);
		return -1;
	}
	if (!(entry.type & MFAT32_DIR)) {
		fprintf(stderr, "This is not a directory, but a file: \"%s\"\n", entry.full_name);
		return -1;
	}
	fs.current_directory = entry.cluster;
	return 0;
}


void mfat32_chroot ( void )
{
	fs.current_directory = fs.root_directory;
}


int mfat32_download_file ( const char *fat_filename, const char *host_filename )
{
	FILE *fp;
	struct mfat32_dir_entry entry;
	int original_size = -1;
	if (mfat32_dir_find_file(fat_filename, &entry)) {
		fprintf(stderr, "Source file (@SD) cannot be found\n");
		return -1;
	}
	if ((entry.type & MFAT32_DIR)) {
		fprintf(stderr, "Directory cannot be downloaded, only files\n");
		return -1;
	}
	open_object(entry.cluster);
	printf("Downloading %d bytes of data from SD-card file %s to local file %s ...\n", entry.size, entry.full_name, host_filename);
	fp = fopen(host_filename, "wb");
	if (!fp) {
		perror("Cannot create/open local file");
		return -1;
	}
	original_size = entry.size;
	while (entry.size > 0) {
		unsigned char buffer[512];
		int piece_size = (entry.size >= 512 ? 512 : entry.size);
		int ret = read_next_sector(buffer);
		if (ret) {
			fprintf(stderr, "FAT32: shorter file in FAT than by its directory entry size, or I/O error [%d]\n", ret);
			fclose(fp);
			return -1;
		}
		if (fwrite(buffer, piece_size, 1, fp) != 1) {
			perror("Write error at the local side");
			fclose(fp);
			return -1;
		}
		entry.size -= piece_size;
	}
	fclose(fp);
	return original_size;
}
