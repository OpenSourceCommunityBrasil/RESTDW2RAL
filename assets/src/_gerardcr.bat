@echo off
set path_brcc32="D:\IDE\Embarcadero\Studio\7\Bin\brcc32.exe"
if NOT EXIST %path_brcc32% (
  echo "Segundo Path brcc32"
  set path_brcc32="C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\brcc32.exe" 
) 

echo RALRESTDW
%path_brcc32% -fo "../../pkg/delphi/RALRESTDW.dcr" "RALRESTDW.rc"
