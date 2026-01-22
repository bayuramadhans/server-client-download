@echo off
REM Interactive testing guide for File Download System (Windows)

setlocal enabledelayedexpansion
set SERVER_URL=http://localhost:8080

:menu
echo.
echo ========================================
echo File Download System - Test Menu
echo ========================================
echo 1. Check system health
echo 2. List connected clients
echo 3. Download file from restaurant-001
echo 4. Download file from restaurant-002
echo 5. Download file from restaurant-003
echo 6. Download from all clients
echo 7. Check download status
echo 8. Verify downloaded files (checksums)
echo 9. View server logs
echo 10. View client logs
echo 11. Clean up downloads
echo 0. Exit
echo.

set /p choice="Enter your choice: "

if "%choice%"=="1" goto check_health
if "%choice%"=="2" goto list_clients
if "%choice%"=="3" goto download_001
if "%choice%"=="4" goto download_002
if "%choice%"=="5" goto download_003
if "%choice%"=="6" goto download_all
if "%choice%"=="7" goto check_status
if "%choice%"=="8" goto verify_files
if "%choice%"=="9" goto server_logs
if "%choice%"=="10" goto client_logs
if "%choice%"=="11" goto cleanup
if "%choice%"=="0" goto exit

echo Invalid option
pause
goto menu

:check_health
echo Checking system health...
curl -s %SERVER_URL%/health
echo.
pause
goto menu

:list_clients
echo Listing connected clients...
curl -s %SERVER_URL%/api/clients
echo.
pause
goto menu

:download_001
call :download_file restaurant-001
goto menu

:download_002
call :download_file restaurant-002
goto menu

:download_003
call :download_file restaurant-003
goto menu

:download_all
echo Downloading from all clients...
echo.
call :download_file restaurant-001
echo.
call :download_file restaurant-002
echo.
call :download_file restaurant-003
pause
goto menu

:download_file
set client_id=%1
echo Triggering download from %client_id%...

REM Create temporary file for response
curl -s -X POST %SERVER_URL%/api/download -H "Content-Type: application/json" -d "{\"client_id\": \"%client_id%\", \"file_path\": \"$HOME/file_to_download.txt\"}" > temp_response.json

REM Display response
type temp_response.json
echo.

REM Try to extract download_id (basic parsing)
for /f "tokens=2 delims=:," %%a in ('findstr "download_id" temp_response.json') do (
    set download_id=%%a
    set download_id=!download_id:"=!
    set download_id=!download_id: =!
)

if defined download_id (
    echo.
    echo Download ID: !download_id!
    echo Monitoring progress for 30 seconds...
    echo.
    
    REM Monitor progress
    for /l %%i in (1,1,15) do (
        timeout /t 2 /nobreak >nul
        curl -s %SERVER_URL%/api/downloads/!download_id! > temp_status.json
        
        REM Check if completed
        findstr /C:"completed" temp_status.json >nul
        if !errorlevel!==0 (
            echo [OK] Download completed!
            type temp_status.json
            echo.
            goto :download_done
        )
        
        REM Check if failed
        findstr /C:"failed" temp_status.json >nul
        if !errorlevel!==0 (
            echo [ERROR] Download failed
            type temp_status.json
            echo.
            goto :download_done
        )
        
        echo   Checking status... (%%i/15)
    )
)

:download_done
if exist temp_response.json del temp_response.json
if exist temp_status.json del temp_status.json
goto :eof

:check_status
set /p download_id="Enter download ID: "
if "%download_id%"=="" (
    echo Download ID cannot be empty
    pause
    goto menu
)

echo Checking status for download: %download_id%
curl -s %SERVER_URL%/api/downloads/%download_id%
echo.
pause
goto menu

:verify_files
echo Verifying downloaded files...
echo.

if not exist checksums.txt (
    echo [ERROR] checksums.txt not found. Run setup.bat first.
    pause
    goto menu
)

REM Check each downloaded file
for %%f in (downloads\*_file_to_download.txt) do (
    echo Checking: %%~nxf
    
    REM Determine source
    echo %%f | findstr "restaurant-001" >nul
    if !errorlevel!==0 set "original=test-files\restaurant-001\file_to_download.txt"
    
    echo %%f | findstr "restaurant-002" >nul
    if !errorlevel!==0 set "original=test-files\restaurant-002\file_to_download.txt"
    
    echo %%f | findstr "restaurant-003" >nul
    if !errorlevel!==0 set "original=test-files\restaurant-003\file_to_download.txt"
    
    if defined original (
        echo   Comparing checksums...
        certutil -hashfile "!original!" MD5 > temp_orig.txt
        certutil -hashfile "%%f" MD5 > temp_down.txt
        
        fc temp_orig.txt temp_down.txt >nul
        if !errorlevel!==0 (
            echo   [OK] Checksum match! File integrity verified.
        ) else (
            echo   [ERROR] Checksum mismatch! File may be corrupted.
        )
        
        del temp_orig.txt temp_down.txt
    )
    echo.
)

if not exist "downloads\*_file_to_download.txt" (
    echo No downloaded files found in .\downloads\
)

pause
goto menu

:server_logs
echo Server logs (last 50 lines):
docker-compose logs --tail=50 server
pause
goto menu

:client_logs
echo.
echo Available clients:
echo   1. restaurant-001
echo   2. restaurant-002
echo   3. restaurant-003
set /p client_num="Enter client number (1-3): "

if "%client_num%"=="1" docker-compose logs --tail=50 client-restaurant-001
if "%client_num%"=="2" docker-compose logs --tail=50 client-restaurant-002
if "%client_num%"=="3" docker-compose logs --tail=50 client-restaurant-003
if not "%client_num%"=="1" if not "%client_num%"=="2" if not "%client_num%"=="3" echo Invalid selection

pause
goto menu

:cleanup
echo This will delete all files in .\downloads\
set /p confirm="Are you sure? (yes/no): "

if /i "%confirm%"=="yes" (
    del /q downloads\* 2>nul
    echo [OK] Downloads directory cleaned
) else (
    echo Cleanup cancelled
)

pause
goto menu

:exit
echo Goodbye!
exit /b 0