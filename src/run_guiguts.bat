@echo off

REM Save original path to restore later. This prevents the path from being
REM updated at every run.
set OLDPATH=%PATH%

REM Prefix Strawberry Perl to the path
set PATH=C:\Strawberry\c\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\perl\bin;%PATH%

REM Add older bundled perl directory to the path at the end as a fall-back
REM for users who want to try and use it instead of Strawberry Perl.
set PATH=%PATH%;%cd%\perl;%cd%\perl\lib

REM Prefix tooling directories
set PATH=%cd%\tools\kindlegen;%cd%\tools\tidy;%PATH%

rem set ASPELL_CONF=conf-dir c:/guiguts/tools/aspell/bin

perl guiguts.pl %1

REM Restore original path
set PATH=%OLDPATH%