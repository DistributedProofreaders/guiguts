erase g*.zip
copy other.zip packed.zip
7z a -x!.* -x!packed.zip -x!setting.rc -x!header.txt -x!samples -x!tools -x!wordlist -x!scannos -x!perl -x!Python27 -r packed.zip *.* lib\Tk\Toolbar\tkIcons