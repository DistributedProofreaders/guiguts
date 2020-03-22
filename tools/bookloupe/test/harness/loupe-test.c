#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <glib.h>
#include <bl/bl.h>
#include "testcase.h"
#include "testcaseio.h"

/*
 * Returns FALSE if the test should be considered to have failed.
 * (returns TRUE on pass or expected-fail).
 */
gboolean run_test(const char *filename)
{
    Testcase *testcase;
    gboolean retval;
    testcase=testcase_parse_file(filename);
    if (!testcase)
	return FALSE;
    retval=testcase_run(testcase);
    testcase_free(testcase);
    return retval;
}

int main(int argc,char **argv)
{
    int i;
    gboolean pass=TRUE;
    bl_set_print_handlers();
    for(i=1;i<argc;i++)
	pass&=run_test(argv[i]);
    return pass?0:1;
}
