#ifndef TESTCASE_PARSER_H
#define TESTCASE_PARSER_H

#include <glib.h>
#include <bl/bl.h>

typedef struct {
    char *filename;
    char *contents;
    GString *flag;
    size_t pos;
    char *tag;
    char *tag_text;
} TestcaseParser;

const char *testcase_parser_get_flag(TestcaseParser *parser);
gboolean testcase_parser_get_next_tag(TestcaseParser *parser,const char **tag,
  const char **text);
gboolean testcase_parser_at_eof(TestcaseParser *parser);
TestcaseParser *testcase_parser_new_from_file(const char *filename);
void testcase_parser_free(TestcaseParser *parser);

#endif	/* TESTCASE_PARSER_H */
