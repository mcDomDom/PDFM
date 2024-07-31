@echo off
setlocal

set PATH=C:\Program Files (x86)\GUI Turbo Assembler\BIN;c:\tools;%PATH%
echo %PATH%

cd pdcommon
msdos tasm head.asm
msdos tasm tail.asm

rem FMV TOWNS FMV-181/182/183/184
cd ..\mb8696x
msdos tasm /i..\pdcommon mb8696x.asm

rem FMV TOWNS NE2000 compatible
cd ..\ne2000
rem tasm /i..\pdcommon lgy98.asm
msdos tasm /i..\pdcommon ne2000.asm

rem FM TOWNS FM50L186/187
cd ..\FM50L186
rem tasm /i..\pdcommon FM50L186.asm
msdos tasm /i..\pdcommon FM50L186.asm

cd ..
rem FMV TOWNS FMV-181/182/183/184
rem val /nci /co pdcommon\head mb8696x\mb8696x pdcommon\tail, mb8696x, mb8696x,,
msdos tlink /t/m pdcommon\head mb8696x\mb8696x pdcommon\tail, fmv18x, fmv18xx,,

rem FMV TOWNS NE2000 compatible
rem val /nci /co pdcommon\head ne2000\ne2000 pdcommon\tail, ne2000, ne2000,,
msdos tlink /t/m/s/l pdcommon\head ne2000\ne2000 pdcommon\tail, ne2000fm, ne2000fm,,

rem val /nci /co pdcommon\head ne2000\lgy98 pdcommon\tail, lgy98, lgy98,,
rem tlink /t/m pdcommon\head ne2000\lgy98 pdcommon\tail, lgy98, lgy98,,

rem FM TOWNS FM50L186/187
rem val /nci /co pdcommon\head FM50L186\FM50L186 pdcommon\tail, FM50L186, FM50L186,,
msdos tlink /t/m/s/l pdcommon\head FM50L186\FM50L186 pdcommon\tail, FM50L186, FM50L186,,

