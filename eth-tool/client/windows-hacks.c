#include <winsock2.h>

#define socklen_t int


static int _winsock_init_status = 1;    // 1 = todo, 0 = was OK, -1 = error!

static void xemu_free_sockapi ( void )
{
        if (_winsock_init_status == 0) {
		printf("WINSOCK: before uninit.\n");
                WSACleanup();
                _winsock_init_status = 1;
                printf("WINSOCK: uninitialized.\n");
        }
}

static int xemu_use_sockapi ( void )
{
        WSADATA wsa;
        if (_winsock_init_status <= 0)
                return _winsock_init_status;
        if (WSAStartup(MAKEWORD(2, 2), &wsa)) {
                fprintf(stderr, "Failed to initialize winsock2, error code: %d\n", WSAGetLastError());
                _winsock_init_status = -1;
                return -1;
        }
        if (LOBYTE(wsa.wVersion) != 2 || HIBYTE(wsa.wVersion) != 2) {
                WSACleanup();
                fprintf(stderr, "No suitable winsock API in the implemantion DLL (we need v2.2, we got: v%d.%d), windows system error ...\n", HIBYTE(wsa.wVersion), LOBYTE(wsa.wVersion));
                _winsock_init_status = -1;
                return -1;
        }
        printf("WINSOCK: initialized, version %d.%d\n", HIBYTE(wsa.wVersion), LOBYTE(wsa.wVersion));
        _winsock_init_status = 0;
	atexit(xemu_free_sockapi);
        return 0;
}


static int windows_init ( void )
{
	AllocConsole();
	SetConsoleTitle("M65 eth-tool client");
	SetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), ENABLE_PROCESSED_OUTPUT | ENABLE_WRAP_AT_EOL_OUTPUT);
	SetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT);
	return xemu_use_sockapi();
}



static char *readline ( const char *prompt )
{
	char *buffer = malloc(256);
	if (!buffer)
		return NULL;
	if (prompt)
		printf("%s", prompt);
	char *s = fgets(buffer, 256, stdin);
	if (s) {
		while (*s != 13 && *s != 10 && *s)
			s++;
		*s = 0;
		return buffer;
	} else {
		free(buffer);
		return NULL;
	}
}

static void read_history ( const char *unused )
{
}

static void add_history ( const char *unused )
{
}

static void write_history ( const char *unused )
{
}


static const char some_network_error[] = "I have to invent some winsock2 error handling :-O";


static const char *hstrerror ( int err )
{
	return some_network_error;
}
