@echo off
setlocal enabledelayedexpansion

:: User Inputs
set /p "ts_url_template=Enter TS segment URL template (e.g., https://.../mediafile_@.ts): "
set /p "start_num=Enter start segment number (e.g., 0): "
set /p "end_num=Enter end segment number (e.g., 99): "
set /p "base64_key=Enter Base64 key: "
set /p "iv=Enter IV (32 hex chars, default=00000000000000000000000000000000): "

:: Set default IV if empty
if "!iv!"=="" set iv=00000000000000000000000000000000

:: Convert Base64 key to Hex using PowerShell
for /f "delims=" %%k in ('powershell -Command "[System.BitConverter]::ToString([System.Convert]::FromBase64String('%base64_key%')).Replace('-','').ToLower()"') do set "hex_key=%%k"

:: Generate download list
echo Generating download list...
del download_list.txt 2>nul
for /l %%i in (%start_num%, 1, %end_num%) do (
    set "url=!ts_url_template:@=%%i!"
    echo !url! >> download_list.txt
)

:: Download TS segments
echo Downloading TS segments...
aria2c -i download_list.txt -j 16 -d ts_files --auto-file-renaming=false --optimize-concurrent-downloads

:: Decrypt segments
echo Decrypting TS segments...
cd ts_files
for /l %%i in (%start_num%, 1, %end_num%) do (
    openssl aes-128-cbc -d -in mediafile_%%i.ts -out dec_mediafile_%%i.ts -nosalt -iv %iv% -K %hex_key%
)
cd ..

:: Generate merge list
echo Generating merge list...
del merge_list.txt 2>nul
for /l %%i in (%start_num%, 1, %end_num%) do (
    echo file 'ts_files\dec_mediafile_%%i.ts' >> merge_list.txt
)

:: Merge segments
echo Merging into output.mp4...
ffmpeg -f concat -safe 0 -i merge_list.txt -c copy output.mp4 -y

:: Cleanup
del download_list.txt merge_list.txt 2>nul
echo Done! Output: output.mp4
