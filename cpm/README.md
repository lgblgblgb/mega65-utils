# 8080 (software) emulator for Mega-65 for running original CP/M BDOS with custom CBIOS

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
