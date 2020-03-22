#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <glib.h>
#include <bl/bl.h>
#include "testcaseparser.h"

/*
 * Get the flag (the string of characters which bracket tags in test cases).
 */
const char *testcase_parser_get_flag(TestcaseParser *parser)
{
    char *s=parser->contents;
    if (!parser->flag)
    {
	parser->flag=g_string_new(NULL);
	while(*s>' ' && *s<='~')
	    g_string_append_c(parser->flag,*s++);
    }
    return parser->flag->str;
}

/*
 * Test if the parser has reached the end of the input file
 */
gboolean testcase_parser_at_eof(TestcaseParser *parser)
{
    return !parser->contents[parser->pos];
}

/*
 * Get the next tag (and its associated text, if any) from a test case.
 * Returns: TRUE if successful and FALSE if no more valid tags are present.
 * Callers can call testcase_parser_at_eof() when testcase_parser_get_next_tag()
 * to distinguish EOF and text which isn't a valid tag.
 */
gboolean testcase_parser_get_next_tag(TestcaseParser *parser,const char **tag,
  const char **text)
{
    size_t n;
    char *eol,*endp;
    GString *string;
    g_free(parser->tag);
    parser->tag=NULL;
    g_free(parser->tag_text);
    parser->tag_text=NULL;
    (void)testcase_parser_get_flag(parser);
    if (strncmp(parser->contents+parser->pos,parser->flag->str,
      parser->flag->len))
	return FALSE;
    eol=strchr(parser->contents+parser->pos,'\n');
    if (!eol)
	return FALSE;
    endp=eol-parser->flag->len;
    if (strncmp(endp,parser->flag->str,parser->flag->len))
	return FALSE;
    while(endp>parser->contents && g_ascii_isspace(endp[-1]))
	endp--;
    parser->pos+=parser->flag->len;
    while(g_ascii_isspace(parser->contents[parser->pos]))
	parser->pos++;
    parser->tag=g_strndup(parser->contents+parser->pos,
      endp-(parser->contents+parser->pos));
    parser->pos=eol-parser->contents+1;
    string=g_string_new(NULL);
    while (!testcase_parser_at_eof(parser) &&
      strncmp(parser->contents+parser->pos,parser->flag->str,parser->flag->len))
    {
	eol=strchr(parser->contents+parser->pos,'\n');
	if (eol)
	    n=eol-(parser->contents+parser->pos)+1;
	else
	    n=strlen(parser->contents+parser->pos);
	g_string_append_len(string,parser->contents+parser->pos,n);
	parser->pos+=n;
    }
    parser->tag_text=g_string_free(string,FALSE);
    if (!parser->tag_text)
	parser->tag_text=g_strdup("");
    if (tag)
	*tag=parser->tag;
    if (text)
	*text=parser->tag_text;
    return TRUE;
}

/*
 * Create a testcase parser to read a regular file.
 */
TestcaseParser *testcase_parser_new_from_file(const char *filename)
{
    TestcaseParser *parser;
    gsize len;
    GError *err=NULL;
    parser=g_new0(TestcaseParser,1);
    if (!file_get_contents_text(filename,&parser->contents,&len,&err))
    {
	g_printerr("%s: %s\n",filename,err->message);
	g_error_free(err);
	g_free(parser);
	return NULL;
    }
    if (!g_utf8_validate(parser->contents,len,NULL))
    {
	g_printerr("%s: Does not contain valid UTF-8\n",filename);
	g_free(parser->contents);
	g_free(parser);
	return NULL;
    }
    parser->filename=g_strdup(filename);
    return parser;
}

/*
 * Free a testcase parser.
 */
void testcase_parser_free(TestcaseParser *parser)
{
    g_free(parser->filename);
    g_free(parser->contents);
    if (parser->flag)
	g_string_free(parser->flag,TRUE);
    g_free(parser->tag);
    g_free(parser->tag_text);
    g_free(parser);
}
