# 8080 (software) emulator for Mega-65 for running original CP/M BDOS (and CP/M applications)

This tool tries to implement a CP/M emulator for the Mega-65 with software
emulation of the 8080 CPU. Emulating Z80 would be nicer, but also it's a bigger
task. Hardware level of 8080 or Z80 in M65 would be nice anyway, by the way :)

Please note, that this stuff is intended to run the original CP/M (v2) BDOS.
So it won't understand any non-CP/M-native filesystem at all, and needs an image
file to work. I still prefer to re-write the BDOS as it's done in IS-DOS for
example, it's a clean re-implementation of CP/M with many extras, which can
does directories, other fancy stuffs, but it's still "only" CP/M v2 compatible.
With this method, the core BDOS can be written in 65(CE)02 assembly using M65
Hypervisor DOS for accessing the SD-Card for native FAT32 implementation for
files, etc etc.

This project contains the following major "tricks" (not so much tricks, and
maybe not as good as it can be, but still some ideas and examples on M65):

* C65 basic-stub loader (so you must start the program in C65 mode! Not C64!!)
* Usage of MAP opcode, C65/M65 memory model, etc
* M65 speed control
* "32 bit linear addressing" opcodes
* M65 direct character "WOM" (write-only memory) access
* Usage of some 65CE02 opcodes (but some of them exists on 65C02 or 65816 as
  well, though the opcode bytes can be even different!), like TRB, TSB,
  BBRx, BBSx, SMBx, RMBx, Z-reg pased ops, INW, 16 bit branches, and such.

## Compile

As usual, you need quite decent CA65 (from cc65) assembler with "4510" CPU
support (currently, maybe only git version is good enough for this?). You
also need an average UNIX-or UNIX like (Linux, OSX, even maybe Windows with
cygwin, or some Linux-box solution) development environment, with GNU make,
wget, and other standard utilities. You also need Python to be installed.

You can say 'make' to compile everything, or 'make test' to test the result
in Xemu Mega65 emulation (you need only the binary to be installed somewhere
in your search path, it will fetch things for you, if needed with wget).

## Current problems and limitations

* i8080 emulation is not full enough, missing opcodes still. Some very short
  test programs can run, but not even the original BDOS what is the goal
* Also, some i8080 features are not implemented, like the "half-carry" flag,
  which may cause problems (surly with DAA but there can be other cases too)
* "Terminal" handling is a big mess of unoptimized quickly written code,
  this is not the major point for now
* i8080 emulation has problems with cases when operands/etc would cross the
  64K boundary. Surely it can be handled, but emulation would be slower to
  do this. I think, this case shouldn't be used anyway by a regular CP/M
  program too much ...
* Of course there can be TONS of bogs on opcode emulations ...
* Usage of M65 character-WOM is neat idea to demonstrate the technique, but
  it has a serious problem: after "exiting", screen will be messed up, because
  my i8080 emulator installs ASCII-compatible character generator layout for
  more comfortable usage of I/O routines.
