@echo off

REM Get the Guiguts install directory as the directory containing this batch file
REM using arcane Windows batch file magic.
set GG_DIR=%~dp0
REM Get full pathname of edit file from first argument to batch file
set ED_FILE=%~f1

REM Save original path to restore later. This prevents the path from being
REM updated at every run.
set OLDPATH=%PATH%

REM Prefix Strawberry Perl to the path
set PATH=C:\Strawberry\c\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\perl\bin;%PATH%

REM Add older bundled perl directory to the path at the end as a fall-back
REM for users who want to try and use it instead of Strawberry Perl.
set PATH=%PATH%;%GG_DIR%perl;%GG_DIR%perl\lib

REM Prefix tooling directories
set PATH=%GG_DIR%tools\kindlegen;%GG_DIR%tools\tidy;%PATH%

REM Find guiguts.pl in same folder as this batch file
REM Use full pathname of file to be edited
perl "%GG_DIR%guiguts.pl" "%ED_FILE%"

REM Restore original path
set PATH=%OLDPATH%
