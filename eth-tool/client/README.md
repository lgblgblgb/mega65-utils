# Simple client for eth-tool's "monitor port"

This utility allows to intract with your M65 through the network, if M65 is attached
to an ethernet LAN.

Currently, it's a Linux-specific client. It also contains code from the "BUSE" project,
see here: https://github.com/acozzette/BUSE

## Usage

This tool is a command-line oriented client to be served by your M65 running "eth-tool" as
the server. It works with non-fragmented UDP over IPv4 datagrams.

By default, currently, eth-tool on M65 listens for every IP address ending in '65', and
on port 6510. This may change in the future. eth-tool must be running before you try to
use this client, otherwise it will just try to reach it in an endless loop, what you need
to interrupt with CTRL-C.

You have basically there three ways to use this client:

* `m65-client -h`
* `m65-client 192.168.0.65 6510`
* `m65-client 192.168.0.65 6510 some_command [possible command parameters]`

The first version simply prints some help (and list of available commands). It does not
try to establish connection with M65.

The second and third form already requires eth-tool running on M65 which is has to be
attached to your LAN. In the examples, `192.168.0.65` can be replaced with your own
needs, also the port `6510`, if you re-configured eth-tool and recompiled it to use
a different one.

Third version directly accepts a command to be executed, then client exits. The second
version however present you a shell, where you can use multiple commands one by one before
you exit (by pressing CTRL-C at empty prompt, or using the `exit` command). The command
names are the same though for the command line and interactive versions. You can use
command `help` in the shell to get a summary of available commands. The shell uses
GNU libreadline, so it supports history the usual way (cursor up), however currently
saving history, or custom command completion is not (yet?) supported.

So, an example to issue `sdsize` command:

    m65-client 192.168.0.65 6510 sdsize
    [...]
    (and you get your OS prompt back)

This is the command line syntax.

    m65-client 192.168.0.65 6510
    [...]
    *** Welcome to the M65-client shell! Press CTRL-D to exit with empty command line ***
    m65@192.168.0.65:6510> sdsize
    [...]
    m65@192.168.0.65:6510> exit

This is the interactive shell, you remains there till you exit.

## Available commands

Note: the exact list of available commands, their exact meanings, etc is not fixed yet,
as it's an early stage of the project.

### Command memdump

It reads the first 256K memory of M65 and dumps that into a file named `mem.dmp`.

### Command memrd

This commands requires a parameter (can be hex with 0x or $ prefix) and will cause
to display the memory content of your M65 at the given value. The address itself
is an M65-specific "linear" 28 bit address.

### Command nbd

This is a quite heavy one. It implements an NBD bloack device, with the "storage"
being your M65 via the network. After that, you can use this on your Linux box,
as any other block device, like `/dev/sda` or whatever, just now you need to use
`/dev/nbd0` for example. The exact list of things you must aware of:

* You need NBD kernel module, ie, you need to say `modprobe nbd` as root on your
  Linux first.
* You must run the m65-client as user `root`, since it requires root privileges
  for this operation (but not for the other commands, usually it's safer not to
  run any program as `root`, unless you really need it! general rule ...)
* You must use a device name, usually it's `/dev/nbd0` but if you have anything
  use NBD already, it may need to use another numbered device.
* You must give the device name as a parameter after the `nbd` command.
* You can use both the shell or the command line mode to give this command though.
* There is no way to stop this command, you need to use CTRL-C. **however it is
  very dangerous too, especally, if your nbd device is in use, like mounted, etc
  meanwhile. Be sure you did `umount` for those (if any), and issued a `sync`
  command, also wait for I/O traffic settles down after these (it can take
  a considerable time!!) and stop client only after that! Also, do not turn off
  or reset your M65, loosing the connection with M65 also can cause serious
  problems**
* After successfully start of nbd mode, you can use it as a standard block
  device. Eg, you can even use `fdisk` to inspect the MBR, or you can `mount`
  a partition also shown by `fdisk`. However beware about the warning above!
  Also, be sure, that you use read-only mount mode. Trying to write cause
  async delayed write failures, kernel thinks the write OK, and delays writes
  to gather I/O groupped and then it's already too late to realize it won't
  work. Probably that's a bug in my code though :)

**CURRENTLY write access is NOT supported via NBD!**

### Command sdpart

Displays the partition table of your SD-card on your M65.

### Command sdrd

Reads a given sector (this commands needs a parameter: the sector to be read)
and displays it as a form of hex dump.

### Command sdsize

This commands does an SD card size detection process, by interpolating size
with trying sizes on various decremanted bit mask to be able to figure out
the exact size with the possible less steps. During this command error messages
are normal (sector cannot be read), since this is how it works, actually.

Note: `nbd` actually runs this command first, since it must know the actual size
of the SD-card!

### Command sdtest

Reads and dumps of sector 0 (as a basic test, if it works), and also does a
performance test with reading 1000 sectors, so you must wait a bit. You will
get some kind of stats on this process at the end.

    Running performance test [with reading 1000 sectors].
    Please stand by ...
    DONE.
    Sectors read: 1000
    Total number of retransmissions: 0
    Seconds: 1.295864
    Sectors/second: 771.685918
    Kilobytes/second: 385.842959

### Command test

This is the most basic test, without too much sane goal. It pushes the current
local time of your Linux box onto the M65's screen, and grabs the first line
of your M65 screen displayed on your Linux box. It's only good for testing the
basic functionality of the M65 vs client communication. It also dumps the
UDP packets used for communication, which can help to find problems if this
command is really needed.
