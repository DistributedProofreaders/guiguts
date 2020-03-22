#ifndef TESTCASE_INPUT_H
#define TESTCASE_INPUT_H

#include <glib.h>
#include "testcase.h"

typedef struct {
    char *name;
    char *name_used;
    char *contents;
} TestcaseInput;

gboolean testcase_input_create(Testcase *testcase,TestcaseInput *input,
  GError **error);
gboolean testcase_input_remove(Testcase *testcase,TestcaseInput *input,
  GError **error);
TestcaseInput *testcase_input_new(const char *name,const char *contents);
void testcase_input_free(TestcaseInput *input);

#endif	/* TESTCASE_INPUT_H */
