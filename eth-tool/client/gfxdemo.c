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

#define MAX_ITERATIONS 255


//static int stat[MAX_ITERATIONS+1];


unsigned char fcm_tiles[320*200];
unsigned char fcm_video_ram[2048];
unsigned char custom_palette[0x300];

const unsigned char some_photo[] = {
#include "photo.c"
};



void gfxdemo_mand_render ( double x_center, double y_center, double zoom )
{
	int y_screen;
	//double x_step = 0.0109375L / zoom;
	//double y_step = 0.0083333L / zoom;

	double x_step = 3.0L / 320.0L / zoom;
	double y_step = 2.0L / 200.0L / zoom;

	double y = y_step * 100.0L + y_center;
	for (y_screen = 0; y_screen < 200; y_screen++) {
		int x_screen;
		double x = x_step * -160.0L + x_center;
		int addr = ((y_screen >> 3) * 2560) + ((y_screen & 7) << 3) - 57;
		for (x_screen = 0; x_screen < 320; x_screen++) {
			double z_a = 0, z_b = 0;
			int iterations = MAX_ITERATIONS;
			while (z_a * z_a + z_b * z_b < 4.0L && iterations) {
				register double z_b_temp = 2.0L * z_a * z_b + y;
				z_a = z_a * z_a - z_b * z_b + x;
				z_b = z_b_temp;
				iterations--;
			}
			x += x_step;
			addr += (x_screen & 7) ? 1 : 57;
			//if (x_screen < 36 && y_screen < 10)
			//	printf("ADDR @ XPOS=%d,YPOS=%d is $%X\n", x_screen, y_screen, addr);
			fcm_tiles[addr] = iterations; /*
			fcm_tiles[addr]++;
			stat[iterations] += 1;
			if (iterations)
				putchar('*');
			else
				putchar(' ');*/
		}
		y -= y_step;
		//putchar('\n');
	}
}


static inline unsigned char swap_nibs ( const unsigned char n ) {
	return ((n & 0xF0) >> 4) | ((n & 0x0F) << 4);
}


void create_mand_palette ( void )
{
	for (int a = 0; a < 0x100; a++) {
		int rev = swap_nibs(a);
		custom_palette[a] = rev;
		custom_palette[a+0x100] = rev;
		custom_palette[a+0x200] = rev;
	}
}


// Lame TGA stuff, must be only palette + image, 64000 + 3 * 256 bytes, with normal top left origin, no RLE ...
// So it's a well stripped TGA ... According to my try with GIMP to create, first 18 bytes must be chopped,
// and 64000 + 3 * 256 binary data from there, if it's saved with top left origin, 8 bit palette, 320*200 and no RLE
void gfxdemo_convert_image ( const unsigned char *stripped_tga )
{
	int y;
	for (y = 0; y < 256; y++) {
		custom_palette[y + 0x000] = swap_nibs(*stripped_tga++);
		custom_palette[y + 0x100] = swap_nibs(*stripped_tga++);
		custom_palette[y + 0x200] = swap_nibs(*stripped_tga++);
	}
	for (y = 0; y < 200; y++) {
		int x;
		int addr = ((y >> 3) * 2560) + ((y & 7) << 3) - 57;
		for (x = 0; x < 320; x++) {
			addr += (x & 7) ? 1 : 57;
			fcm_tiles[addr] = *stripped_tga++;
		}
	}
}



void fcm_create_video_ram ( int addr1, int addr2, int limit )
{
	int a;
	addr1 >>= 6;
	limit = (limit >> 6) - 1;
	for (a = 0; a < sizeof fcm_video_ram ;) {
		//printf("Videoram %d tile=%d (addr=$%X)\n", a / 2, addr1, addr1 * 64);
		fcm_video_ram[a++] = addr1 & 0xFF;
		fcm_video_ram[a++] = addr1 >> 8;
		if (addr1 == limit)
			addr1 = addr2 >> 6;
		else
			addr1++;
	}
}



#if 0
int main ( void )
{
	int a;
	render(-0.75, 0, 1);
/*
	for (a = 0; a < MAX_ITERATIONS + 1; a++)
		printf("#%d %d\n", a, stat[a]); */
	for (a = 0; a < 320*200 ; a++) 
		if (screen[a] != 1)
			printf("A %d is zero\n", a);
	return 0;
}
#endif
