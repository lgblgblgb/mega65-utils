# Really lame Makefile just for the purpose ...

PRG	= m65-client
CC	= gcc
CFLAGS	= -Ofast -ffast-math -Wall -I. -DUSE_BUSE -DUSE_READLINE

all:	$(PRG)

photo.c:
	od -t x1 -An -v -j 18 -N 64768 photo.tga | sed 's/^\s*/0x/;s/\s/,0x/g;s/$$/,/' > photo.c

$(PRG): buse.c linux-client.c buse.h minifat32.c minifat32.h gfxdemo.c gfxdemo.h photo.c Makefile
	$(CC) -o $(PRG) $(CFLAGS) buse.c linux-client.c minifat32.c gfxdemo.c -lreadline -lm

clean:
	rm -f $(PRG) *.o

.PHONY: clean
