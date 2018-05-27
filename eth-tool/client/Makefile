# Really lame Makefile just for the purpose ...

PRG		= m65-client
PRGWIN32	= m65-client32.exe
PRGWIN64	= m65-client64.exe
CC		= gcc
CCWIN32		= i686-w64-mingw32-gcc
CCWIN64		= x86_64-w64-mingw32-gcc
CFLAGS		= -Ofast -ffast-math -Wall -I. -DUSE_BUSE -DUSE_READLINE
CFLAGSWIN	= -Ofast -ffast-math -Wall -I. -mconsole

all:	$(PRG)

all-archs:
	$(MAKE) $(PRG) $(PRGWIN32) $(PRGWIN64)

photo.c:
	od -t x1 -An -v -j 18 -N 64768 photo.tga | sed 's/^\s*/0x/;s/\s/,0x/g;s/$$/,/' > photo.c

$(PRG): buse.c linux-client.c buse.h minifat32.c minifat32.h gfxdemo.c gfxdemo.h photo.c Makefile
	$(CC) -o $(PRG) $(CFLAGS) buse.c linux-client.c minifat32.c gfxdemo.c -lreadline -lm

$(PRGWIN32): linux-client.c minifat32.c minifat32.h gfxdemo.c gfxdemo.h photo.c windows-hacks.c Makefile
	$(CCWIN32) -o $(PRGWIN32) $(CFLAGSWIN) linux-client.c minifat32.c gfxdemo.c -lwsock32

$(PRGWIN64): linux-client.c minifat32.c minifat32.h gfxdemo.c gfxdemo.h photo.c windows-hacks.c Makefile
	$(CCWIN64) -o $(PRGWIN64) $(CFLAGSWIN) linux-client.c minifat32.c gfxdemo.c -lwsock32

install: $(PRG)
	cp $(PRG) /usr/local/bin/

clean:
	rm -f $(PRG) $(PRGWIN32) $(PRGWIN64) *.o

.PHONY: clean all all-archs install
