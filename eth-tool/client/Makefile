PRG	= m65-client
SRC	= linux-client.c
CC	= gcc
CFLAGS	= -O3 -Wall

all:	$(PRG)

$(PRG): $(SRC)
	gcc -o $(PRG) $(CFLAGS) $<

clean:
	rm -f $(PRG) *.o

.PHONY: clean
