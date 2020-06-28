#include <stdio.h>

typedef unsigned char byte;

byte test_status[0x80];
byte test_timing_lo[0x80];
byte test_timing_mi[0x80];
byte test_timing_hi[0x80];
byte number_of_results;

extern void test_command ( void );
extern void set_test_mode ( void );
extern void set_c64_mode ( void );

static void test ( byte command, const char *msg )
{
	byte i;
	printf("%s [%02X] ", msg, command);
	test_status[0] = command;
	test_command();
	printf("%02X", test_status[0]);
	for (i = 1; i < number_of_results; i++) {
		printf(" %02X%02X%02X %02X", test_timing_hi[i], test_timing_mi[i], test_timing_lo[i], test_status[i]);
	}
	printf("\n");
}



void main ( void )
{
	set_test_mode();
	*(byte*)0xD681U = 0;
	*(byte*)0xD682U = 0;
	*(byte*)0xD683U = 0;
	*(byte*)0xD684U = 0;
	test(0x02, "Read sect-0");
	set_c64_mode();
}

