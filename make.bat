erase g*.zip
7z a -x!.* -x!setting.rc -x!header.txt -x!*.bat -x!gg.ico -x!tools -x!samples -x!tests -x!perl -x!Python27 -x!*.zip -x!Win*.* -r guiguts-1.0.19.zip *.* lib\Tk\Toolbar\tkIcons 
REM TODO: bundle bookloupe
7z a -x!.* -x!*.exe -r guiguts-1.0.19.zip tools\gutcheck tools\jeebies

REM other.zip contains perl, Python27 and tools
copy other.zip guiguts-win-1.0.19.zip
7z a -x!.* -x!setting.rc -x!header.txt -x!make.bat -x!gg.ico -x!*.zip -x!samples -x!tools -x!wordlist -x!scannos -x!perl -x!Python27 -r guiguts-win-1.0.19.zip *.* lib\Tk\Toolbar\tkIcons