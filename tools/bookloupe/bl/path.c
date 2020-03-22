#ifdef WIN32
#include <windows.h>
#endif
#include <stdlib.h>
#include <glib.h>
#include <bl/bl.h>

/*
 * Return an absolute path to <path>.
 * Note that this function makes no attempt to return a unique path, or
 * to remove "." or ".." entries. It simply returns a path which will
 * be unaffected by subsequent calls to chdir().
 */
char *path_to_absolute(const char *path)
{
#ifdef WIN32
    long len;
    gunichar2 *path2;
    gunichar2 *abs2;
    char *abs;
    path2=g_utf8_to_utf16(path,-1,NULL,NULL,NULL);
    if (!path2)
	return NULL;
    len=GetFullPathNameW(path2,0,NULL,NULL);	/* len includes nul */
    if (!len)
    {
	g_free(path2);
	return NULL;
    }
    abs2=g_new(gunichar2,len);
    len=GetFullPathNameW(path2,len,abs2,NULL);	/* len excludes nul */
    g_free(path2);
    if (!len)
    {
	g_free(abs2);
	return NULL;
    }
    abs=g_utf16_to_utf8(abs2,len,NULL,NULL,NULL);
    g_free(abs2);
    return abs;
#else
    char *s,*abs;
    if (*path=='/')
	abs=g_strdup(path);
    else
    {
	s=g_get_current_dir();
	abs=g_build_filename(s,path,NULL);
	g_free(s);
    }
    return abs;
#endif
}
