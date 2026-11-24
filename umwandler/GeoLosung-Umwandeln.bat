@echo off
rem Wandelt alle de_los*.xml in GLOSjjjj.DAT fuer GeoLosung (GeoWorks 1) um.
rem Ohne Angaben: XML aus diesem Ordner, sonst aus C:\Program Files (x86)\w32los;
rem die DAT-Dateien landen in diesem Ordner.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GeoLosung-Umwandeln.ps1" %*
pause
