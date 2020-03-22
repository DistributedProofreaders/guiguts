INCLUDES=-I$(top_srcdir)
bin_PROGRAMS=bookloupe
pkgdata_DATA=bookloupe.typ
AM_CFLAGS=$(GLIB_CFLAGS)
LIBS=$(GLIB_LIBS)
LDADD=../bl/libbl.la

bookloupe.typ:	bookloupe.typ.in
	sed 's/$$/\r/' $< > $@

HTMLentities.h:	gen-html-entities.sh HTMLlat1.ent HTMLsymbol.ent HTMLspecial.ent
	sh ${srcdir}/gen-html-entities.sh ${srcdir}/HTMLlat1.ent \
	  ${srcdir}/HTMLsymbol.ent ${srcdir}/HTMLspecial.ent > $@

bookloupe.$(OBJEXT): HTMLentities.h

EXTRA_DIST=bookloupe.typ.in gen-html-entities.sh HTMLlat1.ent HTMLsymbol.ent \
	HTMLspecial.ent
CLEANFILES=bookloupe.typ HTMLentities.h
