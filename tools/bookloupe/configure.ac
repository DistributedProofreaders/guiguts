#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_INIT([bookloupe],[2.0],[ali@juiblex.co.uk])
AC_PREREQ(2.59)
AC_CONFIG_AUX_DIR([config])
AC_CONFIG_SRCDIR([bookloupe/bookloupe.c])
AC_CONFIG_FILES([Makefile
bl/Makefile
bookloupe/Makefile
test/Makefile
test/harness/Makefile
test/compatibility/Makefile
test/bookloupe/Makefile
doc/Makefile
])
AM_INIT_AUTOMAKE([no-define 1.11])
AM_SILENT_RULES([yes])
AC_CANONICAL_HOST

##################################################
# Checks for programs.
##################################################
AC_PROG_CC
LT_INIT
# Libtool supports a --disable-shared option to tell it to avoid
# building shared versions of libraries. We don't have any libraries
# but we do want to support building static versions of our executables.
# Libtool can do this (under the right circumstances) so we overload
# this switch for this purpose.
#
# The libtool option that we use (-static-libtool-libs) means to use
# static linking with libraries that supply a .la file and which
# include a non-empty value for "old_library". If the library doesn't
# include a .la file (they are deleted by some distributions), then
# this option will have no effect and likewise if old_library is set
# to '' (eg., if the library was build with --disable-static) then
# again -static-libtool-libs will have no effect.
#
# If old_library is set to a non-empty value, then specifying
# -static-libtool-libs will cause the link to fail if the old library
# cannot be found (libtool will not fallback to a shared library
# in these circumstances). This can happen with Fedora, for example,
# if a main mingw32 library package is installed but not the
# coresponding static sub-package. The solution is to either
# install the relevant static sub-packages or don't use --disable-shared.
AS_IF([test "$enable_shared" = no],[
  LDFLAGS="$LDFLAGS -static-libtool-libs"
])
LT_OUTPUT
ac_compile="./libtool --mode=compile --tag=CC $ac_compile"
ac_link="./libtool --mode=link --tag=CC $ac_link"
PKG_PROG_PKG_CONFIG

##################################################
# Checks for header files.
##################################################

##################################################
# Checks for typedefs, structures, and compiler characteristics.
##################################################

##################################################
# Checks for libraries.
##################################################
PKG_CHECK_MODULES([GLIB],[glib-2.0 >= 2.18])

# Glib 2.30 (at least) doesn't include "-framework Carbon" in Libs.private
# which causes link to fail for static glib on Mac (gnome bug #668152).
# Test for this problem and implement a workaround.
AC_MSG_CHECKING([for Mac OS X Carbon support])
AC_TRY_CPP([
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>
],[have_carbon=yes],[have_carbon=no])
AC_MSG_RESULT([$have_carbon])
AS_IF([test "$have_glib" != no -a "$have_carbon" = yes],[
  AC_MSG_CHECKING([whether -framework Carbon is needed])
  save_CFLAGS="$CFLAGS"
  save_LIBS="$LIBS"
  CFLAGS="$GLIB_CFLAGS"
  LIBS="$GLIB_LIBS"
  AC_TRY_LINK([
  #include <glib.h>
  ],[
  return !g_get_user_special_dir(G_USER_DIRECTORY_DESKTOP);
  ],[framework_carbon=no],[framework_carbon=yes])
  CFLAGS="$save_CFLAGS"
  LIBS="$save_LIBS"
  AC_MSG_RESULT([$framework_carbon])
  AS_IF([test "$framework_carbon" = yes],[
    GLIB_LIBS="$GLIB_LIBS -framework Carbon"
  ])
])

# If we are using a static version of glib then we should define
# GLIB_STATIC_COMPILATION. This isn't needed when glib is built
# only for static use (in which case glibconfig.h will already
# define GLIB_STATIC_COMPILATION).
AS_IF([test "$enable_shared" = no],[
  AC_MSG_CHECKING([whether GLIB_STATIC_COMPILATION needs to be defined])
  save_CFLAGS="$CFLAGS"
  save_LIBS="$LIBS"
  CFLAGS="$GLIB_CFLAGS"
  LIBS="$GLIB_LIBS"
  AC_TRY_LINK([
  #include <glib.h>
  ],[
  return glib_major_version!=2;
  ],[static_compilation=no],[static_compilation=yes])
  CFLAGS="$save_CFLAGS"
  LIBS="$save_LIBS"
  AC_MSG_RESULT([$static_compilation])
  AS_IF([test "$static_compilation" = yes],[
    GLIB_CFLAGS="$GLIB_CFLAGS -DGLIB_STATIC_COMPILATION"
  ])
])

##################################################
# Checks for library functions.
##################################################
save_CFLAGS="$CFLAGS"
save_LIBS="$LIBS"
CFLAGS="$GLIB_CFLAGS"
LIBS="$GLIB_LIBS"
AC_CHECK_FUNCS([g_mkdtemp mkdtemp],[break])
CFLAGS="$save_CFLAGS"
LIBS="$save_LIBS"

##################################################
# Checks for processor independent files.
##################################################

##################################################
# Generate the various configured files
##################################################
AC_OUTPUT
