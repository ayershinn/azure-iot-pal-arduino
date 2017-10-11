@REM Copyright (c) Microsoft. All rights reserved.
@REM Licensed under the MIT license. See LICENSE file in the project root for full license information.

@setlocal EnableExtensions EnableDelayedExpansion
@echo off

call set_build_vars.cmd
if !ERRORLEVEL! NEQ 0 (
    echo Failed to set build vars
    exit /b 1
)

rem -----------------------------------------------------------------------------
rem -- ensure environment variables for sample editing
rem -----------------------------------------------------------------------------
call :ensure_environment ARDUINO_WIFI_SSID
call :ensure_environment ARDUINO_WIFI_PASSWORD
call :ensure_environment ARDUINO_HOST_NAME
call :ensure_environment ARDUINO_HUZZAH_ID
call :ensure_environment ARDUINO_M0_ID
call :ensure_environment ARDUINO_SPARK_ID
call :ensure_environment ARDUINO_HUZZAH_KEY
call :ensure_environment ARDUINO_M0_KEY
call :ensure_environment ARDUINO_SPARK_KEY
if !environment_ok! EQU "bad" (
    exit /b 1
)



rem -----------------------------------------------------------------------------
rem -- download arduino compiler
rem -----------------------------------------------------------------------------
call download_blob.cmd -directory %tools_root% -file %IOTHUB_ARDUINO_VERSION% -check %IOTHUB_ARDUINO_VERSION%\arduino-builder.exe

rem -----------------------------------------------------------------------------
rem -- create test directories
rem -----------------------------------------------------------------------------
call ensure_delete_directory.cmd %work_root%
if !ERRORLEVEL! NEQ 0 (
    exit /b 1
)
mkdir %work_root%
rem -- keep mkdir quiet when work_root == kits_root
mkdir %kits_root% >nul 2>&1

rem // Download all of the samples from the kits, and modify them for release testing
pushd %kits_root%
call %scripts_path%\get_sample.cmd %kits_root% iot-hub-c-huzzah-getstartedkit || exit /b 1
call %scripts_path%\get_sample.cmd %kits_root% iot-hub-c-m0wifi-getstartedkit || exit /b 1
call %scripts_path%\get_sample.cmd %kits_root% iot-hub-c-thingdev-getstartedkit || exit /b 1
popd

rem -----------------------------------------------------------------------------
rem -- build the Azure Arduino libraries in the user_libraries_path
rem -- wipe the user_libraries_path and re-create it
rem -----------------------------------------------------------------------------
call ensure_delete_directory.cmd %user_libraries_path%
if !ERRORLEVEL! NEQ 0 (
    echo Failed to delete directory: %user_libraries_path%
    exit /b 1
)
call make_sdk.cmd %user_libraries_path%
if !ERRORLEVEL! NEQ 0 (
    echo Failed to make sdk in %user_libraries_path%
    exit /b 1
)

rem -----------------------------------------------------------------------------
rem -- download arduino libraries into user_libraries_path
rem -----------------------------------------------------------------------------
mkdir %user_libraries_path%
pushd %user_libraries_path%
git clone https://github.com/adafruit/Adafruit_Sensor
git clone https://github.com/adafruit/Adafruit_DHT_Unified
git clone https://github.com/adafruit/DHT-sensor-library
git clone https://github.com/adafruit/Adafruit_BME280_Library
git clone https://github.com/arduino-libraries/WiFi101
git clone https://github.com/arduino-libraries/RTCZero

rem -----------------------------------------------------------------------------
rem -- convert the Azure Arduino libraries in the user_libraries_path into
rem -- their respective git repos. This is equivalent to a clone followed
rem -- by updating the library contents, but avoids putting robocopy warnings
rem -- into the output.
rem -----------------------------------------------------------------------------

rem -- clone the Azure arduino libraries into temp directories
git clone https://github.com/Azure/azure-iot-arduino AzureIoTHub_temp
git clone https://github.com/Azure/azure-iot-arduino-protocol-mqtt AzureIoTProtocol_MQTT_temp
git clone https://github.com/Azure/azure-iot-arduino-protocol-http AzureIoTProtocol_HTTP_temp
git clone https://github.com/Azure/azure-iot-arduino-utility AzureIoTUtility_temp

rem -- turn the built libraries into proper git repos by giving them their .git folders
call :relocate_git_folders AzureIoTHub
call :relocate_git_folders AzureIoTProtocol_MQTT
call :relocate_git_folders AzureIoTProtocol_HTTP
call :relocate_git_folders AzureIoTUtility

popd


rem -----------------------------------------------------------------------------
rem -- download arduino hardware
rem -----------------------------------------------------------------------------

echo Cloning https://github.com/esp8266/Arduino
mkdir %user_hardware_path% > nul 2>&1
pushd %user_hardware_path%

call %~dp0\ensure_delete_directory.cmd esp8266com
if !ERRORLEVEL! NEQ 0 (
    exit /b 1
)
mkdir esp8266com
cd esp8266com
git clone https://github.com/esp8266/Arduino esp8266
popd




rem -----------------------------------------------------------------------------
rem -- download arduino packages-adafruit-
rem -- error checking is disabled because download_blob doesn't report errors properly
rem -----------------------------------------------------------------------------
call download_blob.cmd -directory %user_packages_path% -file Arduino15-packages-esp8266-2.3.0 -check esp8266\hardware\esp8266\2.3.0\libraries
rem if !ERRORLEVEL! NEQ 0 (
rem     echo Failed to download Arduino15-packages-esp8266-2.3.0
rem     exit /b 1
rem )

call download_blob.cmd -directory %user_packages_path% -file Arduino15-packages-adafruit-1.0.9 -check adafruit\hardware\samd\1.0.9\libraries
rem if !ERRORLEVEL! NEQ 0 (
rem     echo Failed to download Arduino15-packages-adafruit-1.0.9
rem     exit /b 1
rem )

call download_blob.cmd -directory %user_packages_path% -file Arduino15-packages-arduino-1.6.8 -check arduino\hardware\samd\1.6.8\libraries
rem if !ERRORLEVEL! NEQ 0 (
rem     echo Failed to download Arduino15-packages-arduino-1.6.8
rem     exit /b 1
rem )

exit /b 0

rem -----------------------------------------------------------------------------
rem -- Put the .git folders from the temp repos into the actual Arduino 
rem -- library folders and delete the temp repo. The clone is not done in
rem -- this routine because moving the file too soon after the clone can
rem -- provoke access denied errors.
rem
rem -- Also bump the versions in the new libraries
rem -----------------------------------------------------------------------------
:relocate_git_folders
attrib -h %1_temp\.git
move %1_temp\.git %1\.git
attrib +h %1\.git
pushd !scripts_path!
PowerShell.exe -ExecutionPolicy Bypass -Command "& './bump_version.ps1 ' -oldDir '%user_libraries_path%\%1_temp' -newDir '%user_libraries_path%\%1'"
popd
rd /s /q %1_temp
if !ERRORLEVEL! NEQ 0 (
    echo Failed to bump version in %1
    exit /b 1
) else (
    echo Bumped version in %1
)
exit /b 0

rem -- Make sure this variable is defined
:ensure_environment
if "!%1!"=="" (
    echo Error: %1 is not defined
    set environment_ok="bad"
)
exit /b

