#include <stdio.h>

typedef unsigned char byte;
typedef unsigned int word;
typedef unsigned long int dword;

byte test_status[0x80];
byte test_timing_lo[0x80];
byte test_timing_mi[0x80];
byte test_timing_hi[0x80];
byte number_of_results;

extern void __fastcall__ test_command ( byte cmd );
extern void set_test_mode ( void );
extern void set_c64_mode ( void );

static void test ( byte command, const char *msg )
{
	byte i;
	printf("%s [%02X] ", msg, command);
	//test_status[0] = command;
	test_command(command);
	printf("%02X", test_status[0]);
	for (i = 1; i < number_of_results; i++) {
		printf(" %02X%02X%02X %02X", test_timing_hi[i], test_timing_mi[i], test_timing_lo[i], test_status[i]);
	}
	printf("\n");
}


static void reset_forced ( void )
{
	// Note: the delay loop to wait for status change should give far enough delay for reset to be done!
	// Algorithm is based on mega65-fdisk
	test(0x40, "RESET: clear SDHC");
	test(0x00, "RESET: begin");
	test(0x01, "RESET: end");
	test(0x41, "RESET: set SDHC");
}


static void reset ( void )
{
	if (((*(byte*)0xD680U) & 0x67))
		reset_forced();
}


void main ( void )
{
	printf("Test :)\n");
	set_test_mode();
	// Just to be safe, reset if needed ...
	reset();
	// Reading sector 0, should not be a problem
	*(dword*)0xD681U = 0;
	test(0x02, "Read sect-0");
	// Reading a non-existent sector, then trying to issue the reading of sector 0 again to see, if reset is really needed
	*(dword*)0xD681U = 0xFFFFFFFFUL;
	test(0x02, "Read invalid");
	*(dword*)0xD681U = 0;
	test(0x02, "Read sect-0");
	// At this point we really should do a reset ... Also forcing it, to see the behaviour
	reset_forced();
	// Trying to issue an invalid command
	test(0x76, "Invalid command");
	reset();
	// SDHC off
	test(0x40, "SDHC off?");
	// SDHC on
	test(0x41, "SDHC on?");
	set_c64_mode();
}

