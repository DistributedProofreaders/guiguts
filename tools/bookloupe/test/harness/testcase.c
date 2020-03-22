#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <glib.h>
#include <glib/gstdio.h>
#include <bl/bl.h>
#include "testcase.h"
#include "testcaseinput.h"

GQuark testcase_error_quark(void)
{
    return g_quark_from_static_string("testcase-error-quark");
}

/*
 * Return the length (in bytes) of any common prefix between s1 and s2.
 * The returned length will always represent an exact number of characters.
 */
size_t common_prefix_length(const char *s1,const char *s2)
{
    gunichar c1,c2;
    const char *s=s1;
    while(*s1 && *s2)
    {
	c1=g_utf8_get_char(s1);
	c2=g_utf8_get_char(s2);
	if (c1!=c2)
	    break;
	s1=g_utf8_next_char(s1);
	s2=g_utf8_next_char(s2);
    }
    return s1-s;
}

void print_unexpected(const char *unexpected,gsize differs_at)
{
    int col;
    gunichar c;
    const char *endp,*bol,*s;
    GString *string;
    endp=strchr(unexpected+differs_at,'\n');
    if (!endp)
	endp=unexpected+strlen(unexpected);
    string=g_string_new_len(unexpected,endp-unexpected);
    bol=strrchr(string->str,'\n');
    if (bol)
	bol++;
    else
	bol=string->str;
    col=0;
    s=bol;
    endp=string->str+differs_at;
    while(s<endp)
    {
	c=g_utf8_get_char(s);
	s=g_utf8_next_char(s);
	if (c=='\t')
	    col=(col&~7)+8;
	else if (g_unichar_iswide(c))
	    col+=2;
	else if (!g_unichar_iszerowidth(c))
	    col++;
    }
    g_print("%s\n%*s^\n",string->str,col,"");
    g_string_free(string,TRUE);
}

/*
 * Create all the input files needed by a testcase and, if required,
 * a temporary directory in which to store them.
 */
gboolean testcase_create_input_files(Testcase *testcase,GError **error)
{
    GSList *link,*link2;
    if (testcase->flags&TESTCASE_TMP_DIR)
    {
	testcase->tmpdir=g_strdup("TEST-XXXXXX");
	if (!g_mkdtemp(testcase->tmpdir))
	{
	    g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	      "Failed to create temporary directory: %s",g_strerror(errno));
	    g_free(testcase->tmpdir);
	    testcase->tmpdir=NULL;
	    return FALSE;
	}
    }
    for(link=testcase->inputs;link;link=link->next)
	if (!testcase_input_create(testcase,link->data,error))
	{
	    for(link2=testcase->inputs;link2!=link;link2=link2->next)
		(void)testcase_input_remove(testcase,link2->data,NULL);
	    if (testcase->tmpdir)
	    {
		(void)g_rmdir(testcase->tmpdir);
		g_free(testcase->tmpdir);
		testcase->tmpdir=NULL;
	    }
	    return FALSE;
	}
    return TRUE;
}

/*
 * Remove all the input files used by a testcase and, if created,
 * the temporary directory in which they are stored.
 */
gboolean testcase_remove_input_files(Testcase *testcase,GError **error)
{
    GSList *link;
    GError *tmp_err=NULL;
    gboolean retval=TRUE;
    for(link=testcase->inputs;link;link=link->next)
	if (!testcase_input_remove(testcase,link->data,&tmp_err))
	{
	    if (error && !*error)
		g_propagate_error(error,tmp_err);
	    else
		g_clear_error(&tmp_err);
	    retval=FALSE;
	}
    if (testcase->tmpdir)
    {
	if (g_rmdir(testcase->tmpdir))
	{
	    if (error && !*error)
		g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
		  "Failed to remove temporary directory: %s",g_strerror(errno));
	    retval=FALSE;
	}
	g_free(testcase->tmpdir);
	testcase->tmpdir=NULL;
    }
    return retval;
}

/*
 * Replace every occurance of an input file name in <str> with the
 * filename which holds that input. For input files with fixed names,
 * this is a noop. For input files which use the "XXXXXX" sequence
 * to create a unique filename, the XXXXXX will be replaced with the
 * 6 characters that were chosen to be unique.
 */
char *testcase_resolve_input_files(Testcase *testcase,const char *str)
{
    GSList *link;
    gsize offset,pos;
    char *s;
    TestcaseInput *input;
    GString *filename=g_string_new(str);
    for(link=testcase->inputs;link;link=link->next)
    {
	input=link->data;
	if (!input->name_used)
	{
	    g_warning("%s: Input file uninstantiated",input->name);
	    continue;
	}
	offset=0;
	do
	{
	    s=strstr(filename->str+offset,input->name);
	    if (s)
	    {
		pos=s-filename->str;
		g_string_overwrite(filename,pos,input->name_used);
		offset=pos+strlen(input->name);
	    }
	} while(s);
    }
    return g_string_free(filename,FALSE);
}

gboolean testcase_spawn_bookloupe(Testcase *testcase,char **standard_output,
  GError **error)
{
    gboolean r;
    int i,exit_status;
    char **argv;
    char *output,*s;
    GError *tmp_err=NULL;
    if (testcase->options)
	argv=g_new(char *,g_strv_length(testcase->options)+3);
    else
	argv=g_new(char *,3);
    s=getenv("BOOKLOUPE");
    if (!s)
	s="bookloupe";
    argv[0]=path_to_absolute(s);
    for(i=0;testcase->options && testcase->options[i];i++)
	argv[i+1]=testcase_resolve_input_files(testcase,testcase->options[i]);
    argv[i+1]=testcase_resolve_input_files(testcase,"TEST-XXXXXX");
    argv[i+2]=NULL;
    if (standard_output)
    {
	r=spawn_sync(testcase->tmpdir,argv,&s,&exit_status,error);
	if (r)
	{
	    if (testcase->encoding)
	    {
		output=g_convert(s,-1,"UTF-8",testcase->encoding,NULL,NULL,
		  &tmp_err);
		g_free(s);
		if (!output)
		{
		    g_propagate_prefixed_error(error,tmp_err,
		      "Conversion from %s failed: ",testcase->encoding);
		    r=FALSE;
		}
	    }
	    else
	    {
		output=s;
		if (!g_utf8_validate(s,-1,NULL))
		{
		    g_set_error_literal(error,TESTCASE_ERROR,
		      TESTCASE_ERROR_FAILED,
		      "bookloupe output is not valid UTF-8");
		    r=FALSE;
		}
	    }
	}
    }
    else
    {
	r=spawn_sync(testcase->tmpdir,argv,NULL,&exit_status,error);
	output=NULL;
    }
    g_strfreev(argv);
    if (r && exit_status)
    {
	g_set_error(error,TESTCASE_ERROR,TESTCASE_ERROR_FAILED,
	  "bookloupe exited with code %d",exit_status);
	r=FALSE;
    }
    if (r && standard_output)
	*standard_output=output;
    return r;
}

/*
 * Parse a warning of the form:
 *	[blank line]
 *	<echoed line> (ignored)
 *	"    Line " <number> [" column " <number>] " - " <text> "\n"
 * If not specified, the column is returned as 0.
 * Returns: the number of bytes parsed, or -1 on error.
 */
static ssize_t testcase_parse_warning(Testcase *testcase,const char *output,
  guint *line,guint *column,char **text)
{
    ssize_t offset=0;
    guint64 tmp;
    char *s,*endp;
    if (output[offset]!='\n')
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Unexpected output from bookloupe:\n");
	print_unexpected(output,offset);
	return -1;
    }
    offset++;
    s=strchr(output+offset,'\n');
    if (!s)
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Missing new-line in output from bookloupe:\n");
	print_unexpected(output,offset);
	return -1;
    }
    offset=s-output+1;
    if (!g_str_has_prefix(output+offset,"    Line "))
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Unexpected output from bookloupe:\n");
	offset+=common_prefix_length(output+offset,"    Line ");
	print_unexpected(output,offset);
	return -1;
    }
    offset+=9;
    tmp=g_ascii_strtoull(output+offset,&endp,10);
    if (tmp<1 || tmp>G_MAXUINT || tmp==G_MAXUINT64)
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Unexpected output from bookloupe:\n");
	print_unexpected(output,offset);
	return -1;
    }
    *line=tmp;
    offset=endp-output;
    if (g_str_has_prefix(output+offset," column "))
    {
	offset+=8;
	tmp=g_ascii_strtoull(output+offset,&endp,10);
	if (tmp<1 || tmp>G_MAXUINT || tmp==G_MAXUINT64)
	{
	    g_print("%s: FAIL\n",testcase->basename);
	    g_print("Unexpected output from bookloupe:\n");
	    print_unexpected(output,offset);
	    return -1;
	}
	*column=tmp;
	offset=endp-output;
    }
    else
	*column=0;
    if (!g_str_has_prefix(output+offset," - "))
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Unexpected output from bookloupe:\n");
	offset+=common_prefix_length(output+offset," - ");
	print_unexpected(output,offset);
	return -1;
    }
    offset+=3;
    s=strchr(output+offset,'\n');
    if (!s)
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("Missing new-line in output from bookloupe:\n");
	print_unexpected(output,offset);
	return -1;
    }
    *text=g_strndup(output+offset,s-(output+offset));
    return s-output+1;
}

/*
 * Check the warnings produced by bookloupe against either the
 * unstructured testcase->expected or the structured testcase->warnings
 * as appropriate.
 */
static gboolean testcase_check_warnings(Testcase *testcase,const char *output,
  char **xfail)
{
    gboolean r=TRUE;
    size_t offset;
    ssize_t off;
    int i,count_false_positive,count_false_negative;
    int total_false_positive,total_false_negative;
    char *text;
    guint *counts,line,column;
    GSList *link,*link2;
    TestcaseWarning *warning;
    TestcaseLocation *location;
    *xfail=NULL;
    if (testcase->expected)
    {
	if (strcmp(output,testcase->expected))
	{
	    g_print("%s: FAIL\n",testcase->basename);
	    offset=common_prefix_length(output,testcase->expected);
	    if (!offset && !output[offset])
		g_print("Unexpected zero warnings from bookloupe.\n");
	    else
	    {
		g_print("Unexpected output from bookloupe:\n");
		print_unexpected(output,offset);
	    }
	    return FALSE;
	}
	return TRUE;
    }
    counts=g_new0(guint,g_slist_length(testcase->warnings));
    for(offset=0;output[offset];)
    {
	off=testcase_parse_warning(testcase,output+offset,&line,&column,&text);
	if (off<0)
	{
	    r=FALSE;
	    break;
	}
	offset+=off;
	for(link=testcase->warnings,i=0;link;link=link->next,i++)
	{
	    warning=link->data;
	    if (strcmp(warning->text,text))
		continue;
	    for(link2=warning->locations;link2;link2=link2->next)
	    {
		location=link2->data;
		if (location->line!=line || location->column!=column)
		    continue;
		counts[i]++;
		break;
	    }
	    if (link2)
		break;
	}
	if (!link)
	{
	    g_print("%s: FAIL\n",testcase->basename);
	    g_print("Unexpected warning from bookloupe:\n");
	    if (column)
		g_print("    Line %u column %u - %s\n",line,column,text);
	    else
		g_print("    Line %u - %s\n",line,text);
	    r=FALSE;
	    g_free(text);
	    break;
	}
	g_free(text);
    }
    count_false_positive=total_false_positive=0;
    count_false_negative=total_false_negative=0;
    for(link=testcase->warnings,i=0;r && link;link=link->next,i++)
    {
	warning=link->data;
	if (!counts[i] && warning->is_real && !warning->xfail)
	{
	    location=warning->locations->data;
	    g_print("%s: FAIL\n",testcase->basename);
	    g_print("Missing warning from bookloupe:\n");
	    if (location->column)
		g_print("    Line %u column %u - %s\n",location->line,
		  location->column,warning->text);
	    else
		g_print("    Line %u - %s\n",location->line,warning->text);
	    r=FALSE;
	    break;
	}
	else if (warning->xfail)
	{
	    if (warning->is_real)
	    {
		total_false_negative++;
		if (!counts[i])
		    count_false_negative++;
	    }
	    else if (!warning->is_real)
	    {
		total_false_positive++;
		if (counts[i])
		    count_false_positive++;
	    }
	}
    }
    g_free(counts);
    if (count_false_positive && count_false_negative)
	*xfail=g_strdup_printf(
	  "with %d of %d false positives and %d of %d false negatives",
	  count_false_positive,total_false_positive,
	  count_false_negative,total_false_negative);
    else if (count_false_positive)
	*xfail=g_strdup_printf("with %d of %d false positives",
	  count_false_positive,total_false_positive);
    else if (count_false_negative)
	*xfail=g_strdup_printf("with %d of %d false negatives",
	  count_false_negative,total_false_negative);
    return r;
}

/*
 * Run a testcase, returning FALSE on fail or error and
 * TRUE on pass or expected-fail.
 * Suitable message(s) will be printed in all cases.
 */
gboolean testcase_run(Testcase *testcase)
{
    gboolean r;
    size_t pos,offset;
    GString *header;
    char *output,*filename,*s,*xfail=NULL;
    GError *error=NULL;
    if (!testcase_create_input_files(testcase,&error))
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("%s\n",error->message);
	g_error_free(error);
	return FALSE;
    }
    if (testcase->expected || testcase->warnings)
	r=testcase_spawn_bookloupe(testcase,&output,&error);
    else
    {
	r=testcase_spawn_bookloupe(testcase,NULL,&error);
        output=NULL;
    }
    if (!r)
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("%s\n",error->message);
	g_error_free(error);
	(void)testcase_remove_input_files(testcase,NULL);
	return FALSE;
    }
    filename=testcase_resolve_input_files(testcase,"TEST-XXXXXX");
    if (!testcase_remove_input_files(testcase,&error))
    {
	g_print("%s: FAIL\n",testcase->basename);
	g_print("%s\n",error->message);
	g_error_free(error);
	return FALSE;
    }
    if (testcase->expected || testcase->warnings)
    {
	header=g_string_new("\n\nFile: ");
	g_string_append(header,filename);
	g_string_append(header,"\n");
	if (!g_str_has_prefix(output,header->str))
	{
	    g_print("%s: FAIL\n",testcase->basename);
	    g_print("Unexpected header from bookloupe:\n");
	    offset=common_prefix_length(output,header->str);
	    print_unexpected(output,offset);
	    r=FALSE;
	}
	pos=header->len;
	if (r)
	{
	    /* Skip the summary */
	    s=strstr(output+pos,"\n\n");
	    if (s)
		pos=s-output+2;
	    else
	    {
		g_print("%s: FAIL\n",testcase->basename);
		g_print("Unterminated summary from bookloupe:\n%s\n",
		  output+pos);
		r=FALSE;
	    }
	}
	g_string_free(header,TRUE);
	r=testcase_check_warnings(testcase,output+pos,&xfail);
    }
    g_free(filename);
    g_free(output);
    if (r)
    {
	if (xfail)
	    g_print("%s: PASS (%s)\n",testcase->basename,xfail);
	else
	    g_print("%s: PASS\n",testcase->basename);
    }
    g_free(xfail);
    return r;
}

/*
 * Free a testcase warning.
 */
void testcase_warning_free(TestcaseWarning *warning)
{
    g_slist_foreach(warning->locations,(GFunc)g_free,NULL);
    g_slist_free(warning->locations);
    g_free(warning->text);
    g_free(warning);
}

/*
 * Free a testcase.
 */
void testcase_free(Testcase *testcase)
{
    g_free(testcase->basename);
    g_slist_foreach(testcase->inputs,(GFunc)testcase_input_free,NULL);
    g_slist_free(testcase->inputs);
    g_free(testcase->expected);
    g_slist_foreach(testcase->warnings,(GFunc)testcase_warning_free,NULL);
    g_slist_free(testcase->warnings);
    g_free(testcase->encoding);
    g_strfreev(testcase->options);
    g_free(testcase);
}
