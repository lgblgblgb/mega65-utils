TAP_DEVICE	= mega65

#M65_BITSTREAM	= /home/lgb/prog_here/mega65-core/bin/nexys4ddr.bit.NEWEST-BEFORE
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr.bit.NEWEST-BEFORE
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr.bit
#M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr-on-vega-good-old.bit
M65_BITSTREAM	= ../../mega65-core/bin/nexys4ddr-on-vega.bit
#M65_MON_LOADER	= /usr/local/bin/mega65-monitor_load
M65_MON_LOADER	= ../../mega65-core/src/tools/monitor_load

CBMCONVERT	= cbmconvert
XEMU		= ../../bin/xmega65.native
SUDO		= sudo
CA65		= ca65
LD65		= ld65

STARTADDR	= 0x801

PRGS		= tool
DISKIMAGE	= tool.d81
TARGETS		= $(PRGS) $(DISKIMAGE)
OBJECTS		= ethernet.o main.o icmp_ping.o iputils.o ui.o

LD65CFG		= ld65.cfg
LABELFILE	= tool.label
MAPFILE		= tool.map
ALLDEPENDS	= $(LD65CFG) Makefile common.i65
CA65FLAGS	= -g -t none -D STARTADDR=1
LD65FLAGS       = -Ln $(LABELFILE) -m $(MAPFILE) -vm -C $(LD65CFG) -v -S $(STARTADDR)


all:	$(TARGETS)

$(DISKIMAGE): $(PRGS)
	$(CBMCONVERT) -v2 -D8o $(DISKIMAGE) $(PRGS)

%.o: %.a65 $(ALLDEPENDS)
	$(CA65) $(CA65FLAGS) -l $(@:.o=.list) -o $@ $<

tool:	$(OBJECTS)
	$(LD65) $(LD65FLAGS) -o $@ $(OBJECTS)

delete-arp-cache:
	$(SUDO) arp -d 192.168.0.65 || true
	$(SUDO) ip addr add 10.10.10.1/24 dev $(TAP_DEVICE) || true

tapcfg:
	test ! "`whoami`" = "root"
	$(SUDO) ip tuntap add mode tap user `whoami` $(TAP_DEVICE)
	$(SUDO) ip addr add 10.10.10.1/24 dev $(TAP_DEVICE)
	$(SUDO) ip link set $(TAP_DEVICE) up
	ip link list $(TAP_DEVICE)

board:	tool
	$(MAKE) delete-arp-cache
	$(M65_MON_LOADER) -r -4 -b $(M65_BITSTREAM) tool

xemu:	$(DISKIMAGE)
	test ! "`whoami`" = "root"
	ip link list $(TAP_DEVICE) 2>/dev/null || $(MAKE) tapcfg
	$(MAKE) delete-arp-cache
	$(XEMU) -ethertap $(TAP_DEVICE),debug -8 $(DISKIMAGE)

clean:
	rm -f $(TARGETS) $(OBJECTS) $(OBJECTS:.o=.list) uart.sock dump.mem $(MAPFILE) $(LABELFILE)

.PHONY: clean board xemu tapcfg delete-arp-cache
