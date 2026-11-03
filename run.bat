@echo off
chcp 65001 > nul
title ระบบแดชบอร์ดลูกชิ้น 4 สาขา + AI Vision
echo =========================================================
echo    กำลังเริ่มระบบแดชบอร์ดลูกชิ้น 4 สาขา และ AI Vision...
echo =========================================================
echo.
echo กำลังเปิดเว็บที่ http://localhost:8080 ...
start "" "http://localhost:8080/dashboard.html"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
