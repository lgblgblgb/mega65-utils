# Ethernet test-program for Mega65

Currently, it can:

* Receiving and replying to ARP requests
* Identify itself by IPv4 target address "last octet policy" (by default: 65)
* Receiving ICMP echo request, answering with reply, aka "ping" (no bigger frames than 256 bytes on ethernet level)

Work-in-progess features:

* TFTP server, you can upload/download files from your Mega65 through the network
* DHCP client, M65 can require an IP address for itself (though it can easily store other obtained features as well, netmask, gateway, DNS server, etc)
* Simply UDP console to access utility via the network

Planned features:

* Send ARP requests, handle answer (needed to initiate transfer by our own, not just replying somebody)
* Manual IP config, user can set IP configuration manually
* Ping utility: you can even ping other hosts from M65 for testing purposes. This requires to SEND ARP requests though, and also, we need to aware of our netmask, gateway etc.
* MIIM register dump (if it will work) will be replaced with sane info (link-status, etc)
* Re-program MAC address by user, instead of using what this utility find at the I/O space
* TFTP server can really load/save files from/to SD-card, rather than test storage in the memory
* NTP time sync: use NTP servers on Internet to obtain time, and set our TOD in CIA (can be seen via TI$ in C65 BASIC). Again it requires what ping utility as well.

Undecided:

* Use 80 column display instead of 40
* Use C65 mode by default for the BASIC loader
* Use a "log area" on the screen, where user can seen activity, what happened, etc, not just bare counters and confusing tons of hex dumps everywhere on the screen.

Certainly NOT (well never say never, but ...):

* Anything doing TCP. It's a very simple, non-connection oriented protocol handling. TCP is not that. Maybe we need uIP for that.



### common.i65

Currently the "header file" which is included by all assembly sources.
Contains assembler set-up directives, definitions of some common values, memory addresses,
macros, and .GLOBAL statements to import/export needed symbols.

### dhcp.a65

DHCP level protocol handling.

### ethernet.a65

Ethernet level routines, and ARP handling.

### icmp_ping.a65

ICMP level simple answering, now only dealing with ICMP echo requests (with reply) aka "ping". No other ICMP received packets are handled at all.

### iputils.a65

Various IPv4 related routines, and helpers, including even UDP related wrappers.

### ld65.cfg

The configuration file for the LD65 linker.

### main.a65

The main program.

### Makefile

Makefile for the project.

You can use `make board` to actually test the result on the Nexys4 board. You may need to review Makefile settings though and modify settings first.

### tftpd.a65

Handles TFTP procotol.

### ui.a65

Well, the "user interface", errr, let's say some very stupid and simple functions to show hex bytes, counters, keyboard checking, and stuffs like that.

