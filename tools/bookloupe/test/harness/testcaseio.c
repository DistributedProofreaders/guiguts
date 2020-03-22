#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <glib.h>
#include <bl/bl.h>
#include "testcaseparser.h"
#include "testcaseinput.h"
#include "testcaseio.h"
#include "warningsparser.h"

/*
 * Read a testcase in from a file.
 * On error, print a suitable message using g_printerr and return NULL.
 * The returned testcase should be freed with testcase_free().
 */
Testcase *testcase_parse_file(const char *filename)
{
    Testcase *testcase;
    TestcaseParser *parser;
    TestcaseInput *input=NULL;
    GMarkupParseContext *context;
    GError *err=NULL;
    char *s,*arg;
    const char *tag,*text;
    gboolean found_tag=FALSE;
    parser=testcase_parser_new_from_file(filename);
    if (!parser)
	return NULL;
    if (!*testcase_parser_get_flag(parser))
    {
	g_printerr("%s: Not a valid testcase (flag)\n",filename);
	testcase_parser_free(parser);
	return NULL;
    }
    testcase=g_new0(Testcase,1);
    testcase->basename=g_path_get_basename(filename);
    s=strrchr(testcase->basename,'.');
    if (s)
	*s='\0';
    while(testcase_parser_get_next_tag(parser,&tag,&text))
    {
	if (!input && !strcmp(tag,"INPUT"))
	    input=testcase_input_new("TEST-XXXXXX",text);
	else if (g_str_has_prefix(tag,"INPUT(") && tag[strlen(tag)-1]==')')
	{
	    arg=g_strndup(tag+6,strlen(tag)-7);
	    s=g_path_get_dirname(arg);
	    if (strcmp(s,"."))
	    {
		/*
		 * Otherwise it would be possible to overwrite an arbitary
		 * file on somebody's computer by getting them to run a
		 * testcase!
		 */
		g_printerr(
		  "%s: Input files may not have a directory component\n",arg);
		g_free(s);
		g_free(arg);
		testcase_free(testcase);
		testcase_parser_free(parser);
		return NULL;
	    }
	    g_free(s);
	    testcase->inputs=g_slist_prepend(testcase->inputs,
	      testcase_input_new(arg,text));
	    if (!strstr(arg,"XXXXXX"))
		testcase->flags|=TESTCASE_TMP_DIR;
	    g_free(arg);
	}
	else if (!testcase->expected && !testcase->warnings &&
	  !strcmp(tag,"EXPECTED"))
	    testcase->expected=g_strdup(text);
	else if (!testcase->expected && !testcase->warnings &&
	  !strcmp(tag,"WARNINGS"))
	{
	    context=warnings_parse_context_new(testcase);
	    if (!g_markup_parse_context_parse(context,text,-1,&err) ||
	      !g_markup_parse_context_end_parse(context,&err))
	    {
		g_markup_parse_context_free(context);
		g_printerr("%s\n",err->message);
		g_clear_error(&err);
		testcase_free(testcase);
		testcase_parser_free(parser);
		return NULL;
	    }
	    g_markup_parse_context_free(context);
	}
	else if (!testcase->encoding && !strcmp(tag,"ENCODING"))
	    testcase->encoding=g_strchomp(g_strdup(text));
	else if (!testcase->encoding && !strcmp(tag,"OPTIONS"))
	{
	    testcase->options=g_strsplit(text,"\n",0);
	    g_free(testcase->options[g_strv_length(testcase->options)-1]);
	    testcase->options[g_strv_length(testcase->options)-1]=NULL;
	}
	else
	{
	    g_printerr("%s: Not a valid testcase (%s)\n",filename,tag);
	    testcase_free(testcase);
	    testcase_parser_free(parser);
	    return NULL;
	}
	found_tag=TRUE;
    }
    if (!testcase_parser_at_eof(parser))
    {
	if (found_tag)
	    g_printerr("%s: Not a valid testcase (garbage at end)\n",
	      filename);
	else
	    g_printerr("%s: Not a valid testcase (no valid tags)\n",
	      filename);
	testcase_free(testcase);
	testcase_parser_free(parser);
	return NULL;
    }
    if (!input)
	input=testcase_input_new("TEST-XXXXXX",NULL);
    testcase->inputs=g_slist_prepend(testcase->inputs,input);
    testcase_parser_free(parser);
    return testcase;
}
