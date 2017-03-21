FEATURES {
	STARTADDRESS:	default = $2001;
}
MEMORY {
	LOADADDR:	file = %O, start = %S - 2, size = 2;
	# TODO: what is the exact "TOP" for RAM segment on C65?!
        RAM:		file = %O, start = %S, size = $A000 - %S, define = yes;
}
SEGMENTS {
	LOADADDR:	load = LOADADDR;
	BASICSTUB:	load = RAM, define = yes;
	CODE:		load = RAM;
}
