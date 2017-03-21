## System/file navigator for Mega-65
##
## Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


DISK_IMAGE	= navigator.d81
PRG		= navigator.prg
PRG_ON_DISK	= navigator
SOURCES		= $(shell ls *.asm)
INCLUDES	=
OBJECTS		= $(SOURCES:.asm=.o)
XEMU_SNAPSHOT	= xemu-test.snap
KICKUP		= ../KICKUP.M65
SDIMG		= ../sdcard.img
SDIMG_GZ	= ../sdcard.img.gz
DEBUG_LOG	= debug.log
LD65_CFG	= navigator.ld
ALL_DEPENDS	= Makefile
XEMU_OPTS	= -8 $(DISK_IMAGE) -kickup $(KICKUP) -sdimg $(SDIMG) -kicked 255
KICKUP_URL	= http://github.lgb.hu/xemu/files/KICKUP.M65
SDIMG_URL	= http://github.lgb.hu/xemu/files/sd-card-image-for-xemu-xmega65.img.gz
CA65_OPTS	= -t none
LD65_OPTS	= -C $(LD65_CFG)

XEMU_M65	= xemu-xmega65
C1541		= c1541
CA65		= ca65
LD65		= ld65
WGET		= wget
RM		= rm
GUNZIP		= gunzip


all: $(DISK_IMAGE)

%.o: %.asm $(ALL_DEPENDS) $(INCLUDES)
	$(CA65) $(CA65_OPTS) -o $@ $<

$(PRG): $(OBJECTS) $(LD65_CFG) $(ALL_DEPENDS)
	$(LD65) $(LD65_OPTS) -o $@ $(OBJECTS)

$(DISK_IMAGE): $(PRG) $(ALL_DEPENDS)
	$(RM) -f $@
	echo format lgb-test,00 d81 $@ | $(C1541)
	echo write $(PRG) $(PRG_ON_DISK) | $(C1541) $@

test: $(DISK_IMAGE) $(ALL_DEPENDS) $(KICKUP) $(SDIMG)
	$(MAKE) $(XEMU_SNAPSHOT)
	$(XEMU_M65) $(XEMU_OPTS) -snapload $(XEMU_SNAPSHOT)

test-debug: $(DISK_IMAGE) $(ALL_DEPENDS) $(KICKUP) $(SDIMG)
	$(MAKE) $(XEMU_SNAPSHOT)
	XEMU_DEBUG_FILE=$(DEBUG_LOG) $(XEMU_M65) $(XEMU_OPTS) -snapload $(XEMU_SNAPSHOT)

$(XEMU_SNAPSHOT):
	$(MAKE) $(DISK_IMAGE)
	@echo "**** NO Xemu snapshot ($(XEMU_SNAPSHOT)) for quick testing method."
	@echo "**** We will create one for you, please read the following carefully:"
	@echo "Please let Xemu/M65 run, and answer for external disk image"
	@echo 'After boot, type this, WITHOUT pressing enter/return: RUN"NAVIGATOR"'
	@echo "Then, just press F9 to exit (and no enter/return key, again!!)."
	@echo "This will write a snapshot file, so next time you will need"
	@echo "only to hit ENTER to test the new navigator version without"
	@echo "waiting for M65 to boot, or whatever. After the snapshot creation step,"
	@echo 'you'll only need to say "make test" to build and test with Xemu.'
	@echo "**** Please hit ENTER now to proceed the described task"
	@read some
	$(RM) -f $(XEMU_SNAPSHOT)
	$(XEMU_M65) $(XEMU_OPTS) -snapsave $(XEMU_SNAPSHOT)

clean:
	$(RM) -f $(PRG) *.o $(DISK_IMAGE) uart.sock dump.mem $(DEBUG_LOG) $(SDIMG_GZ)

$(KICKUP):
	$(WGET) -O $@ $(KICKUP_URL)

$(SDIMG):
	$(RM) -f $(SDIMG_GZ) $(SDIMG)
	$(WGET) -O $(SDIMG_GZ) $(SDIMG_URL)
	@echo "*** Extracting SD-card image, this may take a while ..."
	$(GUNZIP) $(SDIMG_GZ)

distclean:
	$(MAKE) clean
	$(RM) -f $(XEMU_SNAPSHOT) $(KICKUP) $(SDIMG)

.PHONY: all clean distclean test test-debug

