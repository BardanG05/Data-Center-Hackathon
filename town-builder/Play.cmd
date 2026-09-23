@echo off
set "GODOT=%~dp0..\.tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Open project.godot in the standard Godot 4 editor and press F5.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
