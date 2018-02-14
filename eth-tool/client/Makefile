# Really lame Makefile just for the purpose ...

PRG	= m65-client
CC	= gcc
CFLAGS	= -O2 -Wall -I. -DUSE_BUSE -DUSE_READLINE

all:	$(PRG)

$(PRG): buse.c linux-client.c buse.h minifat32.c minifat32.h Makefile
	gcc -o $(PRG) $(CFLAGS) buse.c linux-client.c minifat32.c -lreadline

clean:
	rm -f $(PRG) *.o

.PHONY: clean
