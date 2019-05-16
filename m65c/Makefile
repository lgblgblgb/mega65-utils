#   Some file-commander like study for Mega65 computer.
#  
#   Copyright (C)2019 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

PRG_M65		= m65c.prg
PRG_M65_C65	= m65c_c65.prg
MAP_M65		= m65c.map
PRG_NAT		= m65c
PRG_WIN		= m65c.exe

TARGETS		= $(PRG_M65) $(PRG_NAT) $(PRG_WIN) $(PRG_M65_C65)

SOURCES_COMMON	= fat32.c main_common.c

CL_M65		= cl65
CC_M65		= cc65
SOURCES_M65	= $(SOURCES_COMMON) main_m65.c asm_m65.a65
CFLAGS_M65	= -t c64 -r -O -Oi -Or -Os --cpu 65c02
LDFLAGS_M65	= -vm -m $(MAP_M65)

CL_NAT		= gcc
SOURCES_NAT	= $(SOURCES_COMMON) main_native.c
CFLAGS_NAT	= -Wall -Wextra -Wshadow -pipe $(shell sdl2-config --cflags)
LDFLAGS_NAT	= $(shell sdl2-config --libs)

CL_WIN		= x86_64-w64-mingw32-gcc
SOURCES_WIN	= $(SOURCES_NAT)
CFLAGS_WIN	= -Wall -Wextra -Wshadow -pipe $(shell x86_64-w64-mingw32-sdl2-config --cflags)
LDFLAGS_WIN	= $(shell x86_64-w64-mingw32-sdl2-config --libs)
DLL_WIN		= $(shell x86_64-w64-mingw32-sdl2-config --prefix)/bin/*.dll

M65_BITSTREAM   = ../../mega65-core/bin/nexys4ddr.bit
M65_MON_LOADER  = ../../mega65-core/src/tools/monitor_load
#XEMU_BIN	= xemu-xmega65
XEMU_BIN	= ../../xemu/build/bin/xmega65.native
WINE_BIN	= wine

TEST_IMAGE	= /home/lgb/.local/share/xemu-lgb/mega65/mega65.img

all: $(TARGETS)

$(PRG_M65): $(SOURCES_M65) *.h *.a65 Makefile
	$(CL_M65) -o $@ $(CFLAGS_M65) $(LDFLAGS_M65) $(SOURCES_M65)

$(PRG_NAT): $(SOURCES_NAT) *.h chr.cdata Makefile
	$(CL_NAT) -o $@ $(CFLAGS_NAT) $(SOURCES_NAT) $(LDFLAGS_NAT)

$(PRG_WIN): $(SOURCES_WIN) *.h chr.cdata Makefile
	$(CL_WIN) -o $@ $(CFLAGS_WIN) $(SOURCES_WIN) $(LDFLAGS_WIN)

$(PRG_M65_C65): $(PRG_M65)
	cp ../c65izer/c65izer $@
	cat $< >> $@

xemu:	$(PRG_M65)
	$(XEMU_BIN) -8 $< -go64 -autoload

xemu65:	$(PRG_M65_C65)
	$(XEMU_BIN) -8 $< -autoload

run:	$(PRG_NAT)
	./$(PRG_NAT) $(TEST_IMAGE)

wine:	$(PRG_WIN)
	cp $(DLL_WIN) .
	$(WINE_BIN) $< $(TEST_IMAGE)

fpga:	$(PRG_M65)
	$(M65_MON_LOADER) -r -4 -b $(M65_BITSTREAM) $<

clean:
	rm -f $(PRG_M65) $(PRG_M65_C65) $(PRG_NAT) $(PRG_WIN) $(MAP_M65) *.o *.s *.dll dump.mem uart.sock

%.s:	%.c Makefile *.h
	$(CC_M65) -o $@ $(CFLAGS_M65) $<
