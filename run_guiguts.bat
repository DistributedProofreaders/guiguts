@echo off

cd %~dp0

set PATH=%cd%\perl;%cd%\perl\lib;%cd%\python27;%cd%\python27\scripts;%cd%\tools\kindlegen;%cd%\tools\tidy;%PATH%

rem set ASPELL_CONF=conf-dir c:/guiguts/tools/aspell/bin


perl guiguts.pl %1
