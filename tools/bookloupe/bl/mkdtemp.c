#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <glib.h>
#include <glib/gstdio.h>
#include "mkdtemp.h"

#if !HAVE_G_MKDTEMP
char *g_mkdtemp(char *template)
{
#if !defined(WIN32) && HAVE_MKDTEMP
    return mkdtemp(template);
#else
    char *s;
    for(;;)
    {
	s=g_strdup(template);
	mktemp(s);
	if (!*s)
	{
	    g_free(s);
	    errno=EEXIST;
	    return NULL;
	}
	if (g_mkdir(s,0700)>=0)
	{
	    strcpy(template,s);
	    g_free(s);
	    return template;
	}
	g_free(s);
    }
#endif	/* !defined(WIN32) && HAVE_MKDTEMP */
}
#endif	/* !HAVE_G_MKDTEMP */
