# Simple client for eth-tool's "monitor port"

Currently, it's a Linux-specific client. It also contains code from the "BUSE" project,
see here: https://github.com/acozzette/BUSE

**Current supported command line only in the test phase as examples**:

Little test, injects actual time onto your M65 screen, and also grabbing the first line of M65 screen:

    ./m65-client 192.168.0.65 6510 test
    $ ./m65-client 192.168.0.65 6510 test
    Sending to server: (192.168.0.65) 192.168.0.65:6510 with initial MTU of 1400 bytes ...
    Entering into communication state.
    DUMP[REQUEST TO SEND; 28 bytes]:
      0000   00 4D 36 35 2A 02 08 00 E0 07 00 00 32 31 3A 33
      0010   36 3A 32 38 01 28 00 00 04 00 00 03
    Request-answer round-trip in msecs: 0.344000
    DUMP[RECEIVED ANSWER; 48 bytes]:
      0000   00 4D 36 35 2A 30 00 00 12 18 3A 38 33 38 20 14
      0010   18 3A 37 31 35 20 01 12 10 3A 30 30 39 20 10 09
      0020   0E 07 3A 30 30 30 20 14 06 14 10 3A 30 30 30 20
    WOW, answer seems to be OK ;-)
    We've read out the first line of your screen  RX:838 TX:715 ARP:009 PING:000 TFTP:000 
    Well, the screen code conversion is not perfect though in this client :-)
    Also, we've injected the current local time on your PC to your M65 screen.

Reads the first two sectors of your SD card, then doing a performance test with reading 1000 sectors:

    ./m65-client 192.168.0.65 6510 sdtest
    ....

SD-card size detection, dictated by the client:

    ./m65-client 192.168.0.65 6510 sdsizetest

    This is **the problem** ... It creates errors (by will) which then "stuck" and no SD works any more :(

Dumping 256K memory (fast+chip RAM) into mem.dmp:

    $ ./m65-client 192.168.0.65 6510 memdump
    Sending to server: (192.168.0.65) 192.168.0.65:6510 with initial MTU of 1400 bytes ...
    Entering into communication state.
    WOW! Dump is completed, 0 retransmission was needed, avg transfer rate is 790.360107 Kbytes/sec.
    $ ls -l mem.dmp 
    -rw-r--r-- 1 lgb lgb 262144 Feb  8 21:34 mem.dmp

**IGNORE** the rest of this README for now!

## Command line syntax:

    m65-client IP-address PORT COMMAND (possible command parameters)

Example:

    m65-client 192.168.0.65 6510 nbd /dev/nbd0

By default, eth-tool on M65 listens for any IP ends in octet '65'. This will change
in the future, with proper DHCP support. Port number should be 6510, unless you've
changed in eth-tool's source.

Available commands and its parameters with usage comments:

### test

Only tests the connection with eth-tool. No parameters after the command name `test`.

### sprite

**TODO**

A simple test, to "upload" a sprite and programming VIC to show it. No other parameters.

### sdcard

**TODO**

A test, which performs testing on access of M65's sdcard. It tries to determine the size
of the card, and even the first few sectors are read and dumped on the screen. No other
parameters.

### nbd /dev/nbdX (usually X=0)

**TODO**

Sets up a network block device consumer, so your Linux OS can see the content of
the SD-card inserted into your M65 as a block device, which can be handled then
the usual way (`fdisk`, `mount`-ing a partition on it, etc).

**Important note: mounting the given nbd device (or a partition on it, to be more precise) is
dangerous, especially if you break the connection in an unexpected way (ie, stopping client, M65's eth-tool,
or anything like this).  Kernel may left the
device in un-synced state. Always unmount it ASAP, especially before you stop
either m65-client on your PC, or eth-tool on your M65! Failing to do so, even can create some
ugly kernel messages**

It's advised to write a shell script which mounts, do the work (eg copy file) then unmounts.

User should have the nbd Linux kernel module installed first:

    modprobe nbd

Then:

     m65-client 192.168.0.65 6510 nbd /dev/nbd0

Note, that both of the `modprobe` command, and m65-client needs `root` privileges. For
m65-client, you can avoid that, by setting the user and permission of /dev/nbd0 (though
I haven't tested that) first. If you have other network block devices used, you may want to
specify another instance than 0 in the device name.

Leave m65-client running! You should see `/dev/nbd0` (or other instance than 0 what you specified) in
`/proc/partitions` (`cat` it!). If fact, you also should see the partitions on the SD-card itself, in the form
of (for example): `nbd0p1`.

Maybe a safer way than mount (though I didn't tested that!!). mtools is a tool designed for
simple mount-less "DOS like operations", ie for DOS' `dir` you have `mdir`, for `copy` you
have `mcopy`. And so on. Though, for this, you need to configure mtools (or given by command
line switch all the time ... for both of device and offset of the partition), also it's possible,
that mtools don't handle FAT32 well enough (or at all) for example.

You can also use regular tools, like `fdisk` to check the partition table of your M65 SD-card (or
probably even modify it, if you're brave enough).

