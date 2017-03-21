# Mega-65 navigator

This little project wants to be some kind of "file manager" or "file navigator"
for Mega-65 with also "system configuration" capabilities. It's (currently) nothing
to do too much with disk images or D81 files, but rather than the SD-Card of Mega-65
accessed directly. Plans:

* Navigate through the whole SD-Card natively
* Allows "mounting" D81 images on the SD-Card (however browsing the content inside is another maybe TODO item)
* File operations maybe (copy, move, rename, search ...)
* Allows to load simple programs for both of C64/C65 modes maybe (if no further disk access is need by the program?)
* Integrated system plugins? (ie: M65 receive program via Ethernet, and such, later maybe some kind of network FS?)
* Integrated "viewer plugins"? (ie: for some graphics formats, text viewing, etc)
* Integrated "config plugins"? (ie: M65 speed control, exit to C64/C65/M65 mode, with speed set, whatever)
* Xemu integration later? (ie: accessing the file system of your OS which runs Xemu for easier file copy/etc ...)
... maybe others ...

I can imagine as a more or less universal M65 utility in the (far) future with capable of doing almost any
file operations within the SD-card, 3.5" disks (or disk images), or even the network and your native
environment (in case of an emulator, I mean), with the ability to quickly check files out (viewer plugins), and
some "configuration tasks" for your M65 as well.

However currently it's not so much :)

This sub-project also wants to demonstrate some easy way of development/testing,
using Xemu/M65: using the snapshot feature of Xemu, so you don't need to wait for
booting the whole stuff again and again. You only need Xemu binary named as xemu-mega65
somewhere in your search path, then only "make test" is needed. If tester snapshot does
not exist, it helps you create one, then you can re-run "make test" again and again without
doing the boring stuff (waiting the emulator to "boot") every time.

This stuff needs to be loaded in C65 (and not C64!) mode.
