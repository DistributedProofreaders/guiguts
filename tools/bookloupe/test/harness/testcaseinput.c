#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#ifdef WIN32
#include <io.h>
#endif
#include <glib.h>
#include <glib/gstdio.h>
#include <bl/bl.h>
#include "testcase.h"
#include "testcaseinput.h"

#ifndef O_BINARY
#define O_BINARY 0
#endif

/*
 * As write(), but with error handling.
 */
static size_t write_file(int fd,const char *buf,size_t count,GError **error)
{
    if (write(fd,buf,count)<count)
    {
	g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	  "Error writing bookloupe input file: %s",g_strerror(errno));
	return -1;
    }
    return count;
}

/*
 * Replace \n with \r\n, U+240A (visible symbol for LF) with \n
 * and U+240D (visible symbol for CR) with \r.
 */
static char *unix2dos(const char *text)
{
    gunichar c;
    const gunichar visible_lf=0x240A;
    const gunichar visible_cr=0x240D;
    GString *string;
    string=g_string_new(NULL);
    while(*text)
    {
	c=g_utf8_get_char(text);
	text=g_utf8_next_char(text);
	if (c=='\n')
	    g_string_append(string,"\r\n");
	else if (c==visible_lf)
	    g_string_append_c(string,'\n');
	else if (c==visible_cr)
	    g_string_append_c(string,'\r');
	else
	    g_string_append_unichar(string,c);
    }
    return g_string_free(string,FALSE);
}

/*
 * Create an input file needed for a testcase (as specified in <input>).
 * The file is written in the encoding specified for communicating with
 * bookloupe. The name_used field of <input> is filled in with the name
 * of the created file (which may be different than the name specified
 * if that contained "XXXXXX" to be replaced by a unique string).
 */
gboolean testcase_input_create(Testcase *testcase,TestcaseInput *input,
  GError **error)
{
    int fd;
    size_t n;
    char *filename,*s,*t;
    GError *tmp_err=NULL;
    if (input->contents)
    {
	if (testcase->encoding)
	{
	    t=unix2dos(input->contents);
	    s=g_convert(t,-1,testcase->encoding,"UTF-8",NULL,&n,&tmp_err);
	    g_free(t);
	    if (!s)
	    {
		g_propagate_prefixed_error(error,tmp_err,
		  "Conversion to %s failed: ",testcase->encoding);
		return FALSE;
	    }
	}
	else
	{
	    s=unix2dos(input->contents);
	    n=strlen(s);
	}
    }
    else
    {
	n=0;
	s=NULL;
    }
    g_free(input->name_used);
    input->name_used=NULL;
    if (testcase->tmpdir)
	filename=g_build_filename(testcase->tmpdir,input->name,NULL);
    else
	filename=g_strdup(input->name);
    if (strstr(input->name,"XXXXXX"))
	fd=g_mkstemp(filename);
    else
	fd=g_open(filename,O_WRONLY|O_CREAT|O_EXCL|O_BINARY,0600);
    if (fd<0)
    {
	g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	  "%s: %s",filename,g_strerror(errno));
	g_free(s);
	return FALSE;
    }
    input->name_used=g_strdup(filename+strlen(filename)-strlen(input->name));
    if (n && write_file(fd,s,n,error)!=n)
    {
	g_free(s);
	close(fd);
	(void)g_unlink(filename);
	g_free(filename);
	g_free(input->name_used);
	input->name_used=NULL;
	return FALSE;
    }
    g_free(s);
    if (close(fd)<0)
    {
	g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	  "%s: %s",filename,g_strerror(errno));
	(void)g_unlink(filename);
	g_free(filename);
	g_free(input->name_used);
	input->name_used=NULL;
	return FALSE;
    }
    g_free(filename);
    return TRUE;
}

/*
 * Remove an input file created with testcase_input_create()
 */
gboolean testcase_input_remove(Testcase *testcase,TestcaseInput *input,
  GError **error)
{
    char *filename;
    if (input->name_used)
    {
	if (testcase->tmpdir)
	    filename=g_build_filename(testcase->tmpdir,input->name_used,NULL);
	else
	    filename=g_strdup(input->name_used);
	if (g_unlink(filename)<0)
	{
	    g_set_error(error,G_FILE_ERROR,g_file_error_from_errno(errno),
	      "%s: %s",filename,g_strerror(errno));
	    return FALSE;
	}
	g_free(filename);
	g_free(input->name_used);
	input->name_used=NULL;
    }
    return TRUE;
}

/* Create a new description of an input file needed for a testcase */
TestcaseInput *testcase_input_new(const char *name,const char *contents)
{
    TestcaseInput *input;
    input=g_new0(TestcaseInput,1);
    input->name=g_strdup(name);
    input->contents=g_strdup(contents);
    return input;
}

/* Free the description of a testcase input file */
void testcase_input_free(TestcaseInput *input)
{
    g_free(input->name);
    g_free(input->name_used);
    g_free(input->contents);
    g_free(input);
}
