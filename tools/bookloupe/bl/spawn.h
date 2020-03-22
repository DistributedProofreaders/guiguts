#ifndef BL_SPAWN_H
#define BL_SPAWN_H

#include <glib.h>

gboolean spawn_sync(const char *working_directory,char **argv,
  char **standard_output,int *exit_status,GError **error);

#endif /* BL_SPAWN_H */
