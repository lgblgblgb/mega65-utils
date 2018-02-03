TAP_DEVICE	= mega65
IPANDMSKTAP	= 10.10.10.1/24
IPM65TAP	= 10.10.10.65
IPM65LAN	= 192.168.0.65

#M65_BITSTREAM	= /home/lgb/prog_here/mega65-core/bin/nexys4ddr.bit.NEWEST-BEFORE
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr.bit.NEWEST-BEFORE
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr.bit
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr-on-vega-good-old.bit
M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr-on-vega.bit
#M65_MON_LOADER	= /usr/local/bin/mega65-monitor_load
M65_MON_LOADER	= ../../mega65-core/src/tools/monitor_load

CBMCONVERT	= cbmconvert
XEMU		= ../../xemu/build/bin/xmega65.native
SUDO		= sudo
ARP		= /usr/sbin/arp
IPUTIL		= /sbin/ip
CA65		= ca65
LD65		= ld65

PRG		= tool
DISKIMAGE	= tool.d81
TARGETS		= $(PRG) $(DISKIMAGE)
OBJECTS		= ethernet.o main.o icmp_ping.o iputils.o ui.o dhcp.o tftp.o monitor.o

LD65CFG		= ld65.cfg
LABELFILE	= $(PRG).label
MAPFILE		= $(PRG).map
ALLDEPENDS	= $(LD65CFG) Makefile common.i65
CA65FLAGS	= -g -t none --list-bytes 0
LD65FLAGS       = -Ln $(LABELFILE) -m $(MAPFILE) -vm -C $(LD65CFG) -v


all:	$(TARGETS)

$(DISKIMAGE): $(PRG)
	$(CBMCONVERT) -v2 -D8o $(DISKIMAGE) $(PRG)

%.o: %.a65 $(ALLDEPENDS)
	$(CA65) $(CA65FLAGS) -l $(@:.o=.list) -o $@ $<

$(PRG):	$(OBJECTS)
	$(LD65) $(LD65FLAGS) -o $@ $(OBJECTS)

bin/$(PRG).prg.gz: $(PRG)
	gzip -9 < $(PRG) > bin/$(PRG).prg.gz.tmp
	mv bin/$(PRG).prg.gz.tmp bin/$(PRG).prg.gz

bin/$(DISKIMAGE).gz: $(DISKIMAGE)
	gzip -9 < $(DISKIMAGE) > bin/$(DISKIMAGE).gz.tmp
	mv bin/$(DISKIMAGE).gz.tmp bin/$(DISKIMAGE).gz

distribute: $(TARGETS)
	$(MAKE) bin/$(PRG).prg.gz
	$(MAKE) bin/$(DISKIMAGE).gz

delete-arp-cache:
	$(SUDO) $(ARP) -d $(IPM65TAP) || true
	$(SUDO) $(ARP) -d $(IPM65LAN) || true

tapcfg:
	test ! "`whoami`" = "root"
	$(SUDO) $(IPUTIL) tuntap add mode tap user `whoami` $(TAP_DEVICE)
	$(SUDO) $(IPUTIL) addr add $(IPANDMSKTAP) dev $(TAP_DEVICE)
	$(SUDO) $(IPUTIL) link set $(TAP_DEVICE) up
	$(IPUTIL) link list $(TAP_DEVICE)

board:	$(PRG)
	$(MAKE) delete-arp-cache
	$(M65_MON_LOADER) -r -4 -b $(M65_BITSTREAM) $(PRG)

xemu:	$(DISKIMAGE)
	test ! "`whoami`" = "root"
	$(IPUTIL) link list $(TAP_DEVICE) 2>/dev/null || $(MAKE) tapcfg
	$(MAKE) delete-arp-cache
	$(XEMU) -ethertap $(TAP_DEVICE),debug -8 $(DISKIMAGE)

clean:
	rm -f $(TARGETS) $(OBJECTS) $(OBJECTS:.o=.list) uart.sock dump.mem $(MAPFILE) $(LABELFILE)

.PHONY: clean board xemu tapcfg delete-arp-cache distribute
