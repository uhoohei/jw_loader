@echo off

set LOADER_DIR=%~dp0
set LOADER_SCRIPTS_DIR=%LOADER_DIR%
set LOADER_DEST_DIR=%LOADER_DIR%
set LOADER_COMPILE_BIN=%QUICK_V3_ROOT%quick\bin\compile_scripts.bat

rem 编译游戏脚本文件
if exist "%LOADER_DEST_DIR%loader.zip" del /s /q "%LOADER_DEST_DIR%loader.zip"
%LOADER_COMPILE_BIN% -i %LOADER_SCRIPTS_DIR% -o %LOADER_DEST_DIR%loader.zip