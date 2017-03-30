; The 64K bank used for 8080 emulation, that is, high 12bits of the linear 28 bit address!
I8080_BANK	= 1

; The page number of "MEMTOP" that is the emulated i8080 memory area. For fully available
; 64K it's $100 (256). Now, it's $F8, since we use the second 64K of chipram, so 2K colour
; RAM is there, which starts as $F800 within the 64K, thus this param is $F8 here.
MEMTOPPAGE	= $F8

; Currently, BIOSPAGE must be MEMTOPPAGE - 1 and BDOSPAGE = MEMTOPPAGE - 2, or the emulator will fail!
BIOSPAGE	= MEMTOPPAGE - 1
BDOSPAGE	= MEMTOPPAGE - 2

JP_OPC_8080     = $C3
HALT_OPC_8080   = $76
M65_BANK_LO	= .LOBYTE(I8080_BANK)
M65_BANK_HI	= .HIBYTE(I8080_BANK)
