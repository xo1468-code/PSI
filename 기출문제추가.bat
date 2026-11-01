@echo off
rem Starts the local helper server and opens the exam import page in the browser.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\serve.ps1" -Open tools/import.html
