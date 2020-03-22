#ifndef BL_TEXTFILEUTILS_H
#define BL_TEXTFILEUTILS_H

#include <glib.h>

gboolean file_get_contents_text(const char *filename,char **contents,
  size_t *length,GError **err);

#endif /* BL_TEXTFILEUTILS_H */
