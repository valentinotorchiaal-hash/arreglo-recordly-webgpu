@echo off
rem Abre el arreglo de Recordly. El codigo esta en arreglar-recordly.ps1, en esta misma carpeta.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0arreglar-recordly.ps1"
echo.
pause
