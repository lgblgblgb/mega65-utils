# Ethernet test-program for Mega65

You can download (probably not the latest version you could get by compiling the source yourself!) a compiled version as a PRG or D81 from the `bin/` directory can be
found here: https://github.com/lgblgblgb/mega65-utils/tree/master/eth-tool/bin

Source: https://github.com/lgblgblgb/mega65-utils/tree/master/eth-tool

## Currently, it can:

* Receiving and replying to ARP requests
* Identify itself by IPv4 target address "last octet policy" (by default: 65)
* Receiving ICMP echo request, answering with reply, aka "ping" (no bigger frames than 256 bytes on ethernet level)
* Answering on an UDP port ("monitor port", by default: 6510), use netcat, like (type something and press enter): `nc -u 192.168.0.65 6510`
* The monitor UDP port also supports a binary protocol with chained sommands to read/write M65's memory or even M65's SD-card (example client is included) allowing remote-mount as block device on Linux
* Trying to use as a TFTP server it always give back an error (by will, details to be implemented)
* Non-working-yet DHCP, work on progress

The "monitor" UDP port (6510) has a binary protocol to specify chained command list with read/write operations even combined. It's a bit like etherload etc solutions, but it's
bidirectional. The "binary protocol" needs a client, which is not provided this time. By using it via eg netcat (`nc`), you can't access it, not to allow to trigger something
by incident (it will just create a text message as reply). There are some details about the protocol in source file `monitor.a65` as a form of comments.

**You can find the client in the client/ directory**

## Future plans

### Work-in-progess features:

* TFTP server, you can upload/download files from your Mega65 through the network
* DHCP client, M65 can require an IP address for itself (though it can easily store other obtained features as well, netmask, gateway, DNS server, etc)
* Simple UDP console to access utility via the network

### Planned features:

* Send ARP requests, handle answer (needed to initiate transfer by our own, not just replying somebody)
* For creating own initialited traffic, we must handle "routing" (ie, using netmask, and use the gateway if target is not our LAN)
* Manual IP config, user can set IP configuration manually
* Ping utility: you can even ping other hosts from M65 for testing purposes. This requires the two "routing" and "ARP sending" features.
* MIIM register dump (if it will work) will be replaced with sane info (link-status, etc)
* Re-program MAC address by user, instead of using what this utility find at the I/O space
* TFTP server can really load/save files from/to SD-card, rather than test storage in the memory
* NTP time sync: use NTP servers on Internet to obtain time, and set our TOD in CIA (can be seen via TI$ in C65 BASIC). Again it requires what ping utility as well.

### Undecided:

* Use 80 column display instead of 40
* Use C65 mode by default for the BASIC loader
* Use a "log area" on the screen, where user can seen activity, what happened, etc, not just bare counters and confusing tons of hex dumps everywhere on the screen.

### Certainly NOT (well never say never, but ...):

* Anything doing TCP. This utility is a very simple, non-connection oriented protocol handling solution. TCP is not that. Maybe we need uIP for that or any fully capable, more heavy weight TCP/IP stack.

### Problems or potentional problems:

* Network security: currently monitor port and TFTP would work for any IP, if connected to the Internet, and incoming traffic is possible from outside, this utility allows that. Easy proposed solution: allow user to set an "admin IP" up, and accept only those (or at least after DHCP / or manual IP config, use the netmask/network to limit allowed sources from there)
* It does not handle tagged (VLAN IDs) ethernet frames (maybe M65 will have hardware support for this, btw)
* It does not accepts IP packets currently with optional header elements (ie, IP header is larger than the default 5 * 4 bytes).
* Answering a request has the easy but not so correct policy to use MAC and IP from the request. It's not always correct, especially, if assymetric routing is used somewhere. However **this was a must** do this way, so we can answer without proper IP setup before
* IP header checksum is not checked on receiving (but created on transmit, this is a must to have a working solution btw)
* UDP header+data checksum is not checked on receiving and not even created on transmitting (but this second one is not compulsory to do in IPv4, but still)
* DHCP is not handled on a clean way, for various reasons, it's a four step protocol and I simplify many things. But most of these problems are connected with topics like if you have multiple DHCP
servers on your LAN, and select which you choose etc ...
* Last asked IP by DHCP is not remembered and tried to be asked again we start "clean" every time, probably a DHCP server will give new IP all the time. Doing this though, requires multiple tries some time: if user goes to another LAN with the remembered IP, and trying that, DHCP server will refuse the allocated old one being "alien" for it at the first time, and we must ask for a new.
* Limited by theory: DHCP server gives a lease time for IP. On a real PC or anything, DHCP runs in the background all the time, and re-issue the IP request if lease time is over. However on M65 we run this utility when we need this.

## Files in the source

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

### monitor.a65

The "monitor" feature, which can be accessed via UDP (by default: port 6510).

### tftp.a65

Handles TFTP procotol.

### ui.a65

Well, the "user interface", errr, let's say some very stupid and simple functions to show hex bytes, counters, keyboard checking, and stuffs like that.

