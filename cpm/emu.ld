FEATURES {
	STARTADDRESS:	default = $2001;
}
MEMORY {
	LOADADDR:	file = %O, start = %S - 2, size = 2;
	ZP:		file = "", define = yes, start = $0002, size = $00F0;
	# TODO: what is the exact "TOP" for RAM segment on C65?!
        RAM:		file = %O, start = %S, size = $A000 - %S, define = yes;
}
SEGMENTS {
	ZEROPAGE:	load = ZP, type = zp;
	LOADADDR:	load = LOADADDR;
	BASICSTUB:	load = RAM, define = yes;
	CODE:		load = RAM;
	PAYLOAD:	load = RAM, define = yes;
	BSS:		load = RAM, type = BSS;
}
