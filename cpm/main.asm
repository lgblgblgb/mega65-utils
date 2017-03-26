.INCLUDE "mega65.inc"

.CODE

.EXPORT app_main
app_main:
	; Remap memory. I prefer now to use colour RAM to be accessed at the top of the CPU's
	; view of 64K


	INC	$D021
	JMP	app_main

