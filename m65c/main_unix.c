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


#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/time.h>
#include <SDL.h>
#include "m65c.h"

#define PIXEL_FORMAT	SDL_PIXELFORMAT_ARGB8888
#define WIDTH		640
#define HEIGHT		200
#define LOGICAL_WIDTH	WIDTH
#define LOGICAL_HEIGHT	(HEIGHT*2)
#define ZOOM		2

static SDL_Window *sdl_win;
static SDL_Renderer *sdl_ren;
static SDL_Texture *sdl_tex;

Uint8 vram[80*25];
Uint8 cram[80*25];
Uint8 bgcol;

static const Uint8 palette_description[16 * 3] = {
	0x00, 0x00, 0x00,
	0xFF, 0xFF, 0xFF,
	0x74, 0x43, 0x35,
	0x7C, 0xAC, 0xBA,
	0x7B, 0x48, 0x90,
	0x64, 0x97, 0x4F,
	0x40, 0x32, 0x85,
	0xBF, 0xCD, 0x7A,
	0x7B, 0x5B, 0x2F,
	0x4f, 0x45, 0x00,
	0xa3, 0x72, 0x65,
	0x50, 0x50, 0x50,
	0x78, 0x78, 0x78,
	0xa4, 0xd7, 0x8e,
	0x78, 0x6a, 0xbd,
	0x9f, 0x9f, 0x9f
};
static Uint32 palette[16];
static const Uint8 font_data[4096] =  {
#include "chr.cdata"
};
static Uint8 font_used[2048];



static Uint8 key_queue[4];
static int key_queue_read_pos, key_queue_write_pos;

static void push_key ( Uint8 key )
{
	int key_queue_write_pos_new = (key_queue_write_pos + 1) & 3;
	if (key_queue_write_pos_new == key_queue_read_pos)
		printf("Key queue is full\n");
	else {
		key_queue[key_queue_write_pos] = key;
		key_queue_write_pos = key_queue_write_pos_new;
	}
}


static Uint8 may_pop_key ( int to_pop )
{
	if (key_queue_read_pos == key_queue_write_pos)
		return 0;
	Uint8 result = key_queue[key_queue_read_pos];
	if (to_pop)
		key_queue_read_pos = (key_queue_read_pos + 1) & 3;
	return result;
}


Uint8 sys_checkkey ( void )
{
	check_events();
	return may_pop_key(0);
}

Uint8 sys_getkey ( void )
{
	check_events();
	return may_pop_key(1);
}

Uint8 sys_waitkey ( void )
{
	for (;;) {
		check_events();
		int key = may_pop_key(1);
		if (key)
			return key;
	}
}


static inline Uint64 get_time ( void )
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (Uint64)tv.tv_sec * 1000000ULL + (Uint64)tv.tv_usec;
}


static Uint64 last_render_time;


static void render_screen ( void )
{
	int pitch;
	Uint32 *pix;
	Uint64 render_start_time = get_time();
	SDL_LockTexture(sdl_tex, NULL, (void**)&pix, &pitch);
	if (pitch != 4 * WIDTH) {
		fprintf(stderr, "FATAL: texture pitch (%d) is not equal to the pre-computed (%d) value.\n", pitch, 4 * WIDTH);
		exit(1);
	}
	// yeah, lame, but not so much performance impact we care about, in this test-stuff ...
	Uint32 bg = palette[bgcol & 15];
	for (int y = 0; y < 200; y++ ) {
		int rampos = (y >> 3) * 80;
		for (int x = 0; x < 80; x++ ) {
			Uint32 fg =   palette[ cram[rampos] & 15];
			Uint8 ch  = font_used[(vram[rampos] << 3) + (y & 7)];
			*pix++ = (ch & 0x80) ? fg : bg;
			*pix++ = (ch & 0x40) ? fg : bg;
			*pix++ = (ch & 0x20) ? fg : bg;
			*pix++ = (ch & 0x10) ? fg : bg;
			*pix++ = (ch & 0x08) ? fg : bg;
			*pix++ = (ch & 0x04) ? fg : bg;
			*pix++ = (ch & 0x02) ? fg : bg;
			*pix++ = (ch & 0x01) ? fg : bg;
			rampos++;
		}
	}
	SDL_UnlockTexture(sdl_tex);
	SDL_RenderClear(sdl_ren);
	SDL_RenderCopy(sdl_ren, sdl_tex, NULL, NULL);
	SDL_RenderPresent(sdl_ren);
	last_render_time = get_time();
	//printf("Screen has been rendered within %d usecs.\n", (int)(last_render_time - render_start_time));
}


static void push_key_from_string ( const Uint8 *p, const char *debug_msg )
{
	printf("UI-KBD: %s [%s]\n", debug_msg, p);
	while (*p) {
		if (*p >= 32 && *p < 127) {
			printf("UI-KBD: ... pushing key: %c\n", *p);
			push_key(*p);
		}
		p++;
	}
}



void check_events ( void )
{
	int need_render = 0;
	SDL_Event event;
	while (SDL_PollEvent(&event) != 0) {
		switch (event.type) {
			case SDL_QUIT:
				exit(0);
				break;
			case SDL_WINDOWEVENT:
				switch (event.window.event) {
					case SDL_WINDOWEVENT_EXPOSED:
						need_render = 1;
						printf("UI: window expose event, marking need for rendering.\n");
						break;
					case SDL_WINDOWEVENT_SHOWN:
						printf("UI: window is shown!\n");
						break;
				}
				break;
			case SDL_TEXTINPUT:
				// SDL is kinda compilcated in relation of keyboard handling ...
				// normal SDL_KEYUP/KEYDOWN (see below) events exists but it cannot represent non-base chars (ie, shifted numbers to get signs like !, etc, or even capital letters)
				// so we must deal with those HERE, and we must deal with other keypressed with those KEYDOWN events ...
				push_key_from_string((Uint8*)event.text.text, "textinput event");
				break;
			case SDL_TEXTEDITING:
				push_key_from_string((Uint8*)event.edit.text, "textediting event");
				break;
			case SDL_KEYUP:
			case SDL_KEYDOWN:
				printf("KeyUp: state=%s repeat=%d scancode=%d sym=%d mod=%d\n", event.key.state == SDL_PRESSED ? "PRESS":"RELEASE", event.key.repeat, event.key.keysym.scancode, event.key.keysym.sym, event.key.keysym.mod);
				if (event.key.state == SDL_PRESSED) {
					//checks if a key is being remapped and prints what the remapping is
					if (event.key.keysym.scancode != SDL_GetScancodeFromKey(event.key.keysym.sym))
						printf("Physical %s key acting as %s key",
							SDL_GetScancodeName(event.key.keysym.scancode),
							SDL_GetKeyName(event.key.keysym.sym));
					int key = event.key.keysym.sym;
					if (key == SDLK_F9) {
						printf("F9 pressed, exiting ...\n");
						exit(0);
					} else if (key > 0 && key < 32) {
						push_key(key);
					}
					/*else if ((event.key.keysym.mod & KMOD_SHIFT) && key >= 'a' && key <= 'z') {
						push_key(key - 'a' + 'A');
					} else if (key > 0 && key < 128) {
						push_key(key);
					}*/
				}
				break;
		}
	}
	if (!need_render && get_time() - last_render_time >= 40000UL) {
		//printf("Unrendered too long, marking need\n");
		need_render = 1;
	}
	if (need_render)
		render_screen();
}


static int sd_fd = -1;
Uint32 sd_size; // in blocks
Uint32 sd_block;
Uint8 sd_buffer[512];


static int sd_seek ( Uint32 n )
{
	if (n >= sd_size) {
		fprintf(stderr, "SD-ERROR: trying to seek over the end of the SD-image!\n");
		return -1;
	}
	if (lseek(sd_fd, (off_t)n << 9, SEEK_SET) == (off_t)-1) {
		perror("SD-ERROR: seek error:");
		return -1;
	}
	return 0;
}


Uint8 sd_read_block ( void )
{
	if (sd_seek(sd_block))
		return -1;
	if (read(sd_fd, sd_buffer, 512) != 512) {
		perror("SD-ERROR: read error:");
		return -1;
	}
	return 0;
}


Uint8 sd_write_block ( void )
{
	if (sd_seek(sd_block))
		return -1;
	if (write(sd_fd, sd_buffer, 512) != 512) {
		perror("SD-ERROR: write error:");
		return -1;
	}
	return 0;
}


static int sd_init ( const char *fn )
{
	printf("SD: trying to open SD card image: %s\n", fn);
	int fd = open(fn, O_RDWR);
	if (fd < 0) {
		perror("open");
		return -1;
	}
	off_t size = lseek(fd, 0, SEEK_END);
	if (size == (off_t)-1) {
		perror("lseek");
		close(fd);
		return -1;
	}
	if (size & 511) {
		fprintf(stderr, "Image file size is not multiple of 512 bytes!\n");
		close(fd);
		return -1;
	}
	sd_size = size >> 9;
	printf("SD: size: %d blocks (%d Mbytes)\n", sd_size, (int)(size >> 20));
	if (sd_size < 0x10000) {
		fprintf(stderr, "Image file is too small, minimum size: 32Mbytes.\n");
		close(fd);
		return -1;
	}
	if (sd_size > 0x4000000) {
		fprintf(stderr, "Image file is too big, maximum size: 32GBytes.\n");
		close(fd);
		return -1;
	}
	sd_fd = fd;
	return 0;
}



void m65c_exit ( Uint8 retval )
{
	printf("Exiting on request with retval of %d\n", retval);
	exit(retval);
}



extern void main_common ( void );



int main ( int argc, char **argv )
{
	if (argc != 2) {
		fprintf(stderr, "Bad usage, please specify path+filename of the SD-card image\n");
		return 1;
	}
	if (sd_init(argv[1])) {
		fprintf(stderr, "SD card image initialization failed\n");
		return 1;
	}
	if (SDL_Init(SDL_INIT_EVERYTHING)) {
		fprintf(stderr, "Cannot initialize SDL2: %s\n", SDL_GetError());
		return 1;
	}
	atexit(SDL_Quit);
	sdl_win = SDL_CreateWindow(
		"Mega65 Commander",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		LOGICAL_WIDTH * ZOOM, LOGICAL_HEIGHT * ZOOM,
		SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_INPUT_FOCUS
	);
	if (!sdl_win) {
		fprintf(stderr, "Cannot create SDL2 window: %s\n", SDL_GetError());
		return 1;
	}
	SDL_ShowWindow(sdl_win);
	sdl_ren = SDL_CreateRenderer(sdl_win, -1, SDL_RENDERER_ACCELERATED);
	if (!sdl_ren) {
		fprintf(stderr, "Cannot create SDL2 renderer: %s\n", SDL_GetError());
		return 1;
	}
	SDL_RenderSetLogicalSize(sdl_ren, LOGICAL_WIDTH, LOGICAL_HEIGHT);
	sdl_tex = SDL_CreateTexture(sdl_ren, PIXEL_FORMAT, SDL_TEXTUREACCESS_STREAMING, WIDTH, HEIGHT);
	if (!sdl_tex) {
		fprintf(stderr, "Cannot create SDL2 texture: %s\n", SDL_GetError());
		return 1;
	}
	SDL_PixelFormat *pixfmt = SDL_AllocFormat(PIXEL_FORMAT);
	if (!pixfmt) {
		fprintf(stderr, "Cannot allocate pixel format: %s\n", SDL_GetError());
		return 1;
	}
	SDL_StartTextInput();
	//bgcol = 6;
	// re-arrange Commodore style charset in a way that it's quite ASCII :)
	// we can use that charset directly for sure without this game ...
	// however, the point to have the same solution as on Mega65, where we
	// don't want to enlarge the binary with a custom charset, and worth to
	// have this trick. But to test this, and better corresponding code for
	// the native version, we do the very same trick here ...
	// NOTE2: we use the second charset (upper+lower case chars) of the CBM
	// fontgen, thus the base + 2048 addition is implied ...
	memcpy(font_used,            font_data + 2048, 2048);	// first copy the whole charset as-is
	memcpy(font_used + 0x40 * 8, font_data + 2048, 8);	// @
	memcpy(font_used + 0x61 * 8, font_data + 2048 + 8, 26 * 8); // small letters

	for (int a = 0; a < 16; a++)
		palette[a] = SDL_MapRGBA(pixfmt, palette_description[a * 3], palette_description[a * 3 + 1], palette_description[a * 3 + 2], 0xFF);
	render_screen();
	main_common();
	fprintf(stderr, "FATAL: main_common() should NOT return, as it's not implemented in the cc65 version either!\n");
	return 1;
}
