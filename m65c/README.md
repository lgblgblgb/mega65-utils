A simple try to make a "file commander" like entity for Mega65. It uses direct SD-card
controller commands, so in theory it supports things, HyperDOS would not otherwise.
Main concept, that the same source can be built for UNIX/Linux environment (with SDL2)
and for Mega65 as well, so it's easier to test. It also means, that major part of th
code is written in C (using cc65 for Mega65). It's probably a target for rewriting in
assembly in the future when it turns out to be a useful thing.

Currently it's ONLY the crude framework, that the same common source can be compiled
and tried on Mega65 (with cc65) and UNIX (native C compiler with SDL2).


make

	Build the project, both of native (UNIX/Linux) and Mega65 version

make run

	Build the project, and run the native version on your PC.

make xemu

	Build the project, and run the Mega65 version with Xemu's Mega65
	emulation.

make fpga

	Build the project, and inject the Mega65 version to the
	FPGA board.

