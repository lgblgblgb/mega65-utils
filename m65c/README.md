A simple try to make a "file commander" like entity for Mega65. It uses direct SD-card
controller commands, so in theory it supports things, HyperDOS would not otherwise.
Main concept, that the same source can be built for UNIX/Linux environment (with SDL2)
and for Mega65 as well, so it's easier to test. It also means, that major part of th
code is written in C (using cc65 for Mega65). It's probably a target for rewriting in
assembly in the future when it turns out to be a useful thing. Goals:

* Have a file commander for Mega65 in general
* Have a file commander for Mega65 can act as a host for network file transfer
* Have a file commander for your UNIX/Linux/Windows able to deal with SD-card images
  for Xemu
* Have a file commander for your UNIX/Linux/Windows able to deal with your Mega65
  via your network
* Develop a FAT32 driver for Mega65 (later can be used for GEOS-65 and similar
  projects as well, maybe)
* Develop some ethernet stuff for Mega65
* Being a test-bed for cross-platform C level development with both of naiive/Mega65
  "output"

Output files:

  m65c.prg	Can be run on Mega65 in C64 mode
  m65c_c65.prg	Can be run on Mega65 in C65 mode
  m65c		Native build (UNIX-like, eg MacOS, Linux)
  m65c.exe	Windows 64 bit executable
  SDL2.dll	needed for Windows

Currently it's ONLY the crude framework, that the same common source can be compiled
and tried on Mega65 (with cc65) and UNIX (native C compiler with SDL2).


make

	Build the project, both of native (UNIX/Linux) and Mega65 version.
	If you don't have tools/SDL2 for Windows build, remove from TARGETS
	in Makefile, and try again.

make run

	Build the project, and run the native version on your PC.

make xemu

	Build the project, and run the Mega65 version with Xemu's Mega65
	emulation.

make wine

	Test windows build with wine.

make fpga

	Build the project, and inject the Mega65 version to the
	FPGA board.

make something.s

	Create the assembly source from a C file using CC65. Useful only to
	check CC65's work, this does not apply on native builds.
