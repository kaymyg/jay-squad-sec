@echo off
REM Jay Squad Sec — Windows build. Run from this folder.
REM Needs Rust: https://rustup.rs (one installer, ~2 min). No admin required.

where cargo >nul 2>nul
if errorlevel 1 (
  echo Rust not found. Install from https://rustup.rs then re-run this script.
  exit /b 1
)

cargo build --release --bin agent
if errorlevel 1 exit /b 1

echo.
echo Build OK: target\release\agent.exe
echo Start monitoring:  target\release\agent.exe
echo Stop it:           Ctrl+C  (or close the window)
echo Alerts are written to jaysec_alerts.log in the folder you start it from.
