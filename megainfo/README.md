# MEGA65info
## A small utility to get information / simple query tools for MEGA65

Copyright (C)2020 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
License: GNU/GPL 3, see file LICENSE

Download latest binary: https://github.com/lgblgblgb/mega65-utils/raw/master/megainfo/bin/mega65info.prg

Must be started on MEGA65 from C64 mode (GO64 first)!

### TODO

* fix RTC and TOD decoding AM/PM, etc
* use IRQ/NMI (CIA 1 and 2) and timers to test things
* maybe measure CIA 1/2 accurance (and PAL/NTSC anomalies) comparing to the RTC
* test refresh rate (do not assume, but test) append to the "SCAN" information
* add various VIC-IV (and maybe VIC-III as well) test screens etc as options
* tests involving the SDcard
