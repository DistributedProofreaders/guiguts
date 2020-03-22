#ifndef BL_MKDTEMP_H
#define BL_MKDTEMP_H

#if !HAVE_G_MKDTEMP
char *g_mkdtemp(char *template);
#endif

#endif /* BL_MKDTEMP_H */
