PRG_M65		= m65c.prg
MAP_M65		= m65c.map
PRG_NAT		= m65c

SOURCES_COMMON	= fat32.c main_common.c

CL_M65		= cl65
SOURCES_M65	= $(SOURCES_COMMON) main_m65.c asm_m65.a65
CFLAGS_M65	=
LDFLAGS_M65	= -t c64 -r -O -Oi -Or -Os -vm -m $(MAP_M65) --cpu 65c02

CL_NAT		= gcc
SOURCES_NAT	= $(SOURCES_COMMON) main_unix.c
CFLAGS_NAT	= -Wall -Wextra -Wshadow -pipe $(shell sdl2-config --cflags)
LDFLAGS_NAT	= $(shell sdl2-config --libs)

M65_BITSTREAM   = ../../mega65-core/bin/nexys4ddr.bit
M65_MON_LOADER  = ../../mega65-core/src/tools/monitor_load
#XEMU_BIN	= xemu-xmega65
XEMU_BIN	= ../../xemu/build/bin/xmega65.native

TEST_IMAGE	= /home/lgb/.local/share/xemu-lgb/mega65/mega65.img

all:	$(PRG_M65) $(PRG_NAT)

$(PRG_M65): $(SOURCES_M65) *.h *.a65 Makefile
	$(CL_M65) -o $@ $(CFLAGS_M65) $(SOURCES_M65) $(LDFLAGS_M65)

$(PRG_NAT): $(SOURCES_NAT) *.h chr.cdata Makefile
	$(CL_NAT) -o $@ $(CFLAGS_NAT) $(SOURCES_NAT) $(LDFLAGS_NAT)

xemu:	$(PRG_M65)
	$(XEMU_BIN) -8 $(PRG_M65) -go64 -autoload

run:	$(PRG_NAT)
	./$(PRG_NAT) $(TEST_IMAGE)

fpga:	$(PRG_M65)
	$(M65_MON_LOADER) -r -4 -b $(M65_BITSTREAM) $(PRG_M65)

clean:
	rm -f $(PRG_M65) $(PRG_NAT) $(MAP_M65) *.o dump.mem uart.sock
