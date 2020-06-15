@echo off

REM Save original path to restore later. This prevents the path from being
REM updated at every run.
set OLDPATH=%PATH%

REM Prefix Strawberry Perl to the path
set PATH=C:\Strawberry\c\bin;C:\Strawberry\perl\site\bin;C:\Strawberry\perl\bin;%PATH%

REM Add older bundled perl directory to the path at the end as a fall-back
REM for users who want to try and use it instead of Strawberry Perl.
set PATH=%PATH%;%~dp0perl;%~dp0perl\lib

REM Prefix tooling directories
set PATH=%~dp0tools\kindlegen;%~dp0tools\tidy;%PATH%

REM Find guiguts.pl in same folder as this batch file
REM Use full pathname of file to be edited
perl %~dp0guiguts.pl %~f1

REM Restore original path
set PATH=%OLDPATH%