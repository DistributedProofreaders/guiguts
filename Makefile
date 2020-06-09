
# version number
VERSION=1.0.25
# DON'T FORGET to update the version number in guiguts.pl too

# zip utility to use
ZIP=zip -rv9

# files to include from the root
INCLUDES=CHANGELOG.md INSTALL.md LICENSE.txt README.md THANKS.md


all: generic win

win: generic
	# until we get tools/ cleaned up, generic and Windows are the same
	cp guiguts-$(VERSION).zip guiguts-win-$(VERSION).zip

generic:
	mkdir guiguts
	# Start with src/
	cp -a src/ guiguts
	# Remove untracked files & directories that might be in src/
	rm -rf guiguts/tools/ guiguts/header.txt guiguts/settings.rc guiguts/data/labels_en.rc
	# Copy over tools & includes
	cp -a tools guiguts
	cp -a $(INCLUDES) guiguts
	$(ZIP) guiguts-$(VERSION).zip guiguts

clean:
	rm -rf guiguts-*.zip guiguts
