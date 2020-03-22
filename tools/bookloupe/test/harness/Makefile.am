INCLUDES=-I$(top_srcdir)
bin_PROGRAMS=loupe-test
AM_CFLAGS=$(GLIB_CFLAGS)
LIBS=$(GLIB_LIBS)

loupe_test_SOURCES=loupe-test.c testcase.c testcase.h testcaseio.c \
	testcaseio.h testcaseparser.c testcaseparser.h testcaseinput.c \
	testcaseinput.h warningsparser.c warningsparser.h
loupe_test_LDADD=../../bl/libbl.la
