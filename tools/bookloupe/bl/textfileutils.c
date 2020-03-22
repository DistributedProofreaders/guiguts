#include <stdlib.h>
#include <stdio.h>
#include <bl/bl.h>

/*
 * Read a file into memory (which should be freed with g_free when no
 * longer required). Returns NULL on error and outputs a suitable error
 * message to stderr.
 * DOS-style line endings and UTF-8 BOM are handled transparently even
 * on platforms which don't normally use these formats.
 */
gboolean file_get_contents_text(const char *filename,char **contents,
  size_t *length,GError **err)
{
    int i;
    unsigned char *raw;
    gsize raw_length;
    GString *string;
    if (!g_file_get_contents(filename,(char **)&raw,&raw_length,err))
	return FALSE;
    string=g_string_new(NULL);
    i=0;
    if (raw_length>=3 && raw[0]==0xEF && raw[1]==0xBB && raw[2]==0xBF)
	i+=3;			/* Skip BOM (U+FEFF) */
    for(;i<raw_length;i++)
	if (raw[i]!='\r')
	    g_string_append_c(string,raw[i]);
    g_free(raw);
    if (length)
	*length=string->len;
    if (contents)
	*contents=g_string_free(string,FALSE);
    else
	g_string_free(string,TRUE);
    return TRUE;
}
