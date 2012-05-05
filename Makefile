
# version number
VERSION=1.0.20
# DON'T FORGET to update the version number in guiguts.pl too

# zip utility to use
ZIP=zip -rv9

# files to exclude
EXCLUDES=.\* \*.zip \*.bat Makefile guiguts setting.rc header.txt footer.txt gg.ico todo.txt COMPILING.txt tools/\* samples/\* tests/\* data/\*


all: win generic


win:
	cp other.zip guiguts-win-$(VERSION).zip
	$(ZIP) guiguts-win-$(VERSION).zip * -x $(EXCLUDES) wordlist/\* scannos/\*
	$(ZIP) guiguts-win-$(VERSION).zip guiguts.bat data/labels_default.rc


generic:
	$(ZIP) guiguts-$(VERSION).zip * -x $(EXCLUDES) \*.exe
	$(ZIP) guiguts-$(VERSION).zip scannos/* wordlist/* -x $(EXCLUDES)
	$(ZIP) guiguts-$(VERSION).zip data/labels_default.rc
	$(ZIP) guiguts-$(VERSION).zip tools/gutcheck/*.* tools/jeebies/*.* tools/DPCustomMono lib/Tk/Toolbar/tkIcons -x .\* \*.exe


data:
	$(ZIP) guiguts-data-$(VERSION).zip data/* -x data/labels_default.rc


clean:
	rm -rf guiguts-*.zip

