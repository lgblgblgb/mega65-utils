FEATURES {
	STARTADDRESS:	default = $2001;
}
MEMORY {
	LOADADDR:	file = %O, start = %S - 2, size = 2;
        RAM:		file = %O, start = %S, size = $A000;
}

SEGMENTS {
	LOADADDR:	load = LOADADDR;
	BASICSTUB:	load = RAM, define = yes;
	CODE:		load = RAM;
}

