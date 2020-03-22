#ifdef WIN32
#include <windows.h>
#endif
#include <stdlib.h>
#include <stdio.h>
#include <glib.h>

/*
 * Handlers for g_print() and g_printerr() which will output via
 * WriteConsoleW when run under MS-Windows and the corresponding
 * stream has not been re-directed. In all other cases, output
 * via stdout and stderr respectively.
 */

#ifdef WIN32
static HANDLE bl_console=0;

static void bl_print_handler_console(const char *string)
{
    long len;
    DWORD dummy;
    gunichar2 *string2;
    string2=g_utf8_to_utf16(string,-1,NULL,&len,NULL);
    if (string2)
    {
	WriteConsoleW(bl_console,string2,len,&dummy,NULL);
	g_free(string2);
    }
}
#endif

static void bl_print_handler_stdout(const char *string)
{
    fputs(string,stdout);
}

static void bl_print_handler_stderr(const char *string)
{
    fputs(string,stderr);
}

void bl_set_print_handlers(void)
{
#ifdef WIN32
    DWORD dummy;
    if (GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE),&dummy))
    {
	bl_console=GetStdHandle(STD_OUTPUT_HANDLE);
	g_set_print_handler(bl_print_handler_console);
    }
    else
#endif
	g_set_print_handler(bl_print_handler_stdout);
#ifdef WIN32
    if (GetConsoleMode(GetStdHandle(STD_ERROR_HANDLE),&dummy))
    {
	if (!bl_console)
	    bl_console=GetStdHandle(STD_ERROR_HANDLE);
	g_set_printerr_handler(bl_print_handler_console);
    }
    else
#endif
	g_set_printerr_handler(bl_print_handler_stderr);
}
