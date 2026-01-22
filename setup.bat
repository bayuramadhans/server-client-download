@echo off
REM Setup script for File Download System Docker simulation (Windows)

echo ========================================
echo File Download System - Docker Setup
echo ========================================
echo.

REM Create directory structure
echo Creating directory structure...
if not exist "test-files\restaurant-001" mkdir "test-files\restaurant-001"
if not exist "test-files\restaurant-002" mkdir "test-files\restaurant-002"
if not exist "test-files\restaurant-003" mkdir "test-files\restaurant-003"
if not exist "downloads" mkdir "downloads"

REM Generate test files (100MB each)
echo Generating test files (100MB each)...
echo This may take a minute...

REM Restaurant 1
if not exist "test-files\restaurant-001\file_to_download.txt" (
    echo   Creating file for restaurant-001...
    fsutil file createnew "test-files\restaurant-001\file_to_download.txt" 104857600
    echo   [OK] restaurant-001/file_to_download.txt created (100MB)
) else (
    echo   [INFO] restaurant-001/file_to_download.txt already exists
)

REM Restaurant 2
if not exist "test-files\restaurant-002\file_to_download.txt" (
    echo   Creating file for restaurant-002...
    fsutil file createnew "test-files\restaurant-002\file_to_download.txt" 104857600
    echo   [OK] restaurant-002/file_to_download.txt created (100MB)
) else (
    echo   [INFO] restaurant-002/file_to_download.txt already exists
)

REM Restaurant 3
if not exist "test-files\restaurant-003\file_to_download.txt" (
    echo   Creating file for restaurant-003...
    fsutil file createnew "test-files\restaurant-003\file_to_download.txt" 104857600
    echo   [OK] restaurant-003/file_to_download.txt created (100MB)
) else (
    echo   [INFO] restaurant-003/file_to_download.txt already exists
)

REM Calculate checksums for verification
echo.
echo Calculating checksums for verification...
certutil -hashfile "test-files\restaurant-001\file_to_download.txt" MD5 > checksums.txt
echo restaurant-001 checksum saved >> checksums.txt
certutil -hashfile "test-files\restaurant-002\file_to_download.txt" MD5 >> checksums.txt
echo restaurant-002 checksum saved >> checksums.txt
certutil -hashfile "test-files\restaurant-003\file_to_download.txt" MD5 >> checksums.txt
echo restaurant-003 checksum saved >> checksums.txt
echo [OK] Checksums saved to checksums.txt

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Directory structure:
echo   - test-files\
echo     - restaurant-001\file_to_download.txt (100MB)
echo     - restaurant-002\file_to_download.txt (100MB)
echo     - restaurant-003\file_to_download.txt (100MB)
echo   - downloads\ (downloads will appear here)
echo.
echo Next steps:
echo   1. Build and start containers: docker-compose up --build
echo   2. Follow the testing guide in test-guide.bat
echo.
pause