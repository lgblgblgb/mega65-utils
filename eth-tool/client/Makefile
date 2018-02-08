# Really lame Makefile just for the purpose ...

PRG	= m65-client
CC	= gcc
CFLAGS	= -O2 -Wall -I.

all:	$(PRG)

$(PRG): buse.c linux-client.c buse.h Makefile
	gcc -o $(PRG) $(CFLAGS) buse.c linux-client.c

clean:
	rm -f $(PRG) *.o

.PHONY: clean
