# Simple client for eth-tool's "monitor port"

Currently, it's a Linux-specific client.

**Current supported command line only**:

    m65-client IP-address PORT test
    m65-client IP-address PORT sdtest
    m65-client IP-address PORT sdsizetest

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

