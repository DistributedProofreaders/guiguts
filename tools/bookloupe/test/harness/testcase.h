#ifndef TESTCASE_H
#define TESTCASE_H

#include <glib.h>

#define TESTCASE_ERROR testcase_error_quark()

typedef enum {
    TESTCASE_ERROR_FAILED
} TestcaseError;

typedef struct {
    guint line;
    guint column;		/* or 0 for unspecified */
} TestcaseLocation;

typedef struct {
    /*
     * Does this warning relate to a real problem in the etext
     * (eg., error and false-negative).
     */
    gboolean is_real;
    /*
     * Do we "expect" BOOKLOUPE to get this wrong
     * (eg., false-negative and false-positive)
     */
    gboolean xfail;
    /*
     * For real problems, the first location should be the
     * actual location of the problem.
     */
    GSList *locations;
    char *text;
} TestcaseWarning;

typedef struct {
    char *basename;
    char *tmpdir;
    GSList *inputs;
    char *expected;
    GSList *warnings;
    char *encoding;	/* The character encoding to talk to BOOKLOUPE in */
    char **options;
    enum {
	TESTCASE_XFAIL=1<<0,
	TESTCASE_TMP_DIR=1<<1,
    } flags;
} Testcase;

GQuark testcase_error_quark(void);
gboolean testcase_run(Testcase *testcase);
void testcase_free(Testcase *testcase);

#endif	/* TESTCASE_H */
