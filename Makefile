
# version number
VERSION=1.0.25
# DON'T FORGET to update the version number in guiguts.pl too

# zip utility to use
ZIP=zip -rv9

# files to include from the root
INCLUDES=CHANGELOG.md INSTALL.md LICENSE.txt README.md THANKS.md


all: generic

generic: common
	# Build tools
	mkdir guiguts/tools
	./tools/package-tools.sh generic $$(pwd)/guiguts/tools
	# Create final zip
	$(ZIP) guiguts-$(VERSION).zip guiguts

win: common
	# Build tools
	mkdir guiguts/tools
	./tools/package-tools.sh win $$(pwd)/guiguts/tools
	# Create final zip
	$(ZIP) guiguts-win-$(VERSION).zip guiguts

mac: common
	# Build tools
	mkdir guiguts/tools
	./tools/package-tools.sh mac $$(pwd)/guiguts/tools
	# Create final zip
	$(ZIP) guiguts-mac-$(VERSION).zip guiguts

common: clean
	mkdir guiguts
	# Start with src/
	cp -a src/ guiguts
	# Remove untracked files & directories that might be in src/
	rm -rf guiguts/tools/ guiguts/header.txt guiguts/setting.rc guiguts/data/labels_en.rc
	# Copy common tools
	cp -a $(INCLUDES) guiguts

clean:
	rm -rf guiguts

distclean: clean
	rm -rf guiguts-*.zip
