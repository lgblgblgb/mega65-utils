# Various C65 / M65 testing tools/utilities

The actual binary version (which can be outdated!) can be found in the
bin/ directory, in the form of invididual PRG files, or a D81 disk image.

Currently:

## sd_status_test

Intended to test MEGA65's SD-card controller. Must be loaded in C64 mode
of MEGA65. Output syntax:

MESSAGE [CMD] status delay status2 delay2 status3 ....

Where MESSAGE is some message from the test program (purpose of the given
test), CMD is the hex value of the issued command. The first 'status' is
the status BEFORE the command was issued, after that pairs of delay and
status to see any status change with the delay measured for that change.

Compile: make sd_status_test.prg

Test on MEGA65 (using M65 and FTDI JTAG module): make sd_status_test_m65

TODO: the "delay" 6 hex digit value should be converted into a sane time
unit :)

## DMAtest

It's intended to test on *REAL* C65s to see some corner cases and not too
well known behaviours of F018 (rev A or B) DMA. Most likely, it can help
to create better C65 implementation in VHDL and/or C65 emulator software.

The description of each tests to be able to interpret the result:

### DMA revision

This test uses a chained DMA list to figure out the DMA revision. The theory
based on the "offset" given by the one byte longer DMA entry of F018B, causing
the different "shifted" interpretation of the second DMA entry. By checking
what address is modified as the COPY operation target, we can decide.

The syntax of the test output:

DMA revision: A 0 00

The first letter A/B means the detected DMA behaviour. The next digit shows
if test should wait (0=no, 1=yes). It should be 0. The last hex byte is the
DMA status register read.

Possible problems:

* border flashes: the test waits for first DMA entry to be done, by checking
  the target. Since DMA is a "CPU stopper" this should not happen and means
  something wrong.
* background flashes: the same as above, but waiting for the second entry
* both of the background and border flashes: show-stopper error, cannot decide
  clearly from the result if it is F018A or F018B


### DMA reg decode echo

This tests tries to find "memory echo" of the DMA register set, ie partly
decoded in the $D7XX area. The number means the low byte of $D7XX where it
founds another "ghost" of the register set first. If it's 00, it means, no
"echo" found.

### CPU IO port

This is the well known addr 0/1 of 6510. On C65, it's for real handled
by VIC-III and only low 3 bits does something. This test is a dual purpose
thing. It just reads the port. Then it looks if DMA can write the CPU IO
port at all, based on reading back _AND_ also the effect (memory banking
changed).

Sytnax of the test output:

CPU IO port: XX YY WW

Where XX is the hex number of the original CPU port value read by CPU.
YY is the value read after we tried DMA to write the CPU port, read
by CPU again. W is a value designed to reflect the bank switching
effect only, in nutshell, it should be 00 if no effect, or anything
other if does.





