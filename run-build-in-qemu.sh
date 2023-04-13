#!/bin/bash

# run-build-in-qemu.sh
# Bash script to a run an esp32 compiled binary in QEmu and capture the outptut
#
# Copyright (C) 2023 tobozo
# https://github.com/tobozo/
# License: MIT
#



ESPTOOL_PY="./esptool/esptool.py"
QEMU_BIN="./qemu-git/build/qemu-system-xtensa"


if [[ "$ENV_DEBUG" != "false" ]]; then
  function _debug { echo "[DEBUG] $1"; }
else
  function _debug { return; }
fi

function exit_with_error { echo "$1"; exit 1; }

echo "[INFO] Validating tools"

[[ ! -f "$ESPTOOL_PY" ]] && exit_with_error "esptool.py is missing"
[[ ! -f "$QEMU_BIN" ]] && exit_with_error "qemu-system-xtensa is missing"

echo "[INFO] Validating input data"

[[ "$ENV_BUILD_FOLDER" == "" ]] && exit_with_error "No build folder provided"
[[ ! -d "$ENV_BUILD_FOLDER" ]] && exit_with_error "No build folder found, aborting"
[[ ! -f "$ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV" ]] && exit_with_error "Missing partitions.csv file in build folder"

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_OTADATA_BIN" ]]; then
  echo "[INFO] Fetching a copy of boot_app0.bin from espressif/arduino-esp32 repository"
  wget -q https://github.com/espressif/arduino-esp32/raw/master/tools/partitions/boot_app0.bin -O "$ENV_BUILD_FOLDER/$ENV_OTADATA_BIN"
fi

[[ ! -f "$ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN" ]] && exit_with_error "Missing app0, check your 'firmware-bin' path"
# TODO: generate partitions.bin from partitions.csv using gen_esp32part.py
[[ ! -f "$ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN" ]] && exit_with_error "Missing partitions.bin, check your 'partitions-bin' path"
[[ ! -f "$ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN" ]] && exit_with_error "Missing bootloader.bin, check your 'bootloader-bin' path"

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN" ]]; then
  echo "[INFO] Creating empty SPIFFS file"
  touch "$ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN"
fi

[[ "$ENV_FLASH_SIZE" =~ ^(2|4|8|16)$ ]] || exit_with_error "Invalid flash size (valid values=2,4,8,16)"
#[[ "$ENV_PSRAM" =~ ^(2M|4M)$ ]] && exit_with_error "Invalid flash size (valid values=2,4,8,16)"
[[ "$ENV_PSRAM" =~ ^(2M|4M)$ ]] && ENV_PSRAM="-m $ENV_PSRAM" || ENV_PSRAM=""
[[ "$ENV_QEMU_TIMEOUT" =~ ^[0-9]{1,3}$ ]] || exit_with_error "Invalid timeout value (valid values=0...999)"
[[ "$ENV_BOOTLOADER_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]] || exit_with_error "Invalid bootloader address (valid values=0x0000...0xffffffff)"
[[ "$ENV_PARTITIONS_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]] || exit_with_error "Invalid partitions address (valid values=0x0000...0xffffffff)"
#[[ "$ENV_PARTITIONS_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]] || exit_with_error "Invalid bootloader address (valid values=0x0000...0xffffffff)"

echo "[INFO] Extracting partitions info from $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV"

OLD_IFS=$IFS

csvdata=`cat $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV | tr -d ' ' | tr '\n' ';'` # remove spaces, replace \n by semicolon

IFS=';' read -ra rows <<< "$csvdata" # split lines

for index in "${!rows[@]}"
do
  IFS=',' read -ra csv_columns <<< "${rows[$index]}" # split columns
  case "${csv_columns[0]}" in
    otadata)  OTADATA_ADDR="${csv_columns[3]}"  ;;
    app0)     FIRMWARE_ADDR="${csv_columns[3]}" ;;
    spiffs)   SPIFFS_ADDR="${csv_columns[3]}"   ;;
    *) _debug "Ignoring ${csv_columns[0]}:${csv_columns[3]}" ;;
  esac
done

_debug "`( set -o posix ; set ) | grep _ADDR`"

IFS=$OLD_IFS

[[ "$OTADATA_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]] || exit_with_error "Invalid otadata address in $ENV_PARTITIONS_CSV file"
[[ "$FIRMWARE_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]] || exit_with_error "Invalid app0 address in $ENV_PARTITIONS_CSV file"


if [[ "$SPIFFS_ADDR" =~ ^0x[0-9a-z-A-Z]{1,8}$ ]]; then
  echo "[WARNING] Invalid or empty spiffs address extracted from $ENV_PARTITIONS_CSV file, overriding"
  $SPIFFS_ADDR="0x290000"
fi

if [[ "$SPIFFS_ADDR" != "$ENV_SPIFFS_ADDR" ]]; then
  echo "[WARNING] SPIFFS address mismatch (csv=$SPIFFS_ADDR, workflow=$ENV_SPIFFS_ADDR)"
fi


echo "[INFO] Building flash image for QEmu"

_debug "Flash Size:   $ENV_FLASH_SIZE"
_debug "Build Folder: $ENV_BUILD_FOLDER"
_debug "Partitions csv file: $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV"
_debug "`cat $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV`"
_debug "$ESPTOOL_PY --chip esp32 merge_bin --fill-flash-size ${ENV_FLASH_SIZE}MB -o flash_image.bin $ENV_BOOTLOADER_ADDR $ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN $ENV_PARTITIONS_ADDR $ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN $OTADATA_ADDR $ENV_BUILD_FOLDER/$ENV_OTADATA_BIN $FIRMWARE_ADDR $ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN $SPIFFS_ADDR $ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN"

$ESPTOOL_PY --chip esp32 merge_bin --fill-flash-size ${ENV_FLASH_SIZE}MB $ENV_PSRAM -o flash_image.bin \
  $ENV_BOOTLOADER_ADDR $ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN \
  $ENV_PARTITIONS_ADDR $ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN \
  $OTADATA_ADDR $ENV_BUILD_FOLDER/$ENV_OTADATA_BIN \
  $FIRMWARE_ADDR $ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN \
  $SPIFFS_ADDR $ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN


echo "[INFO] Running flash image in QEmu"
_debug "QEmu timeout: $ENV_QEMU_TIMEOUT seconds"
_debug "$QEMU_BIN -nographic -machine esp32 -drive file=flash_image.bin,if=mtd,format=raw"

($QEMU_BIN -nographic -machine esp32 -drive file=flash_image.bin,if=mtd,format=raw | tee -a ./logs.txt) &

sleep $ENV_QEMU_TIMEOUT
killall qemu-system-xtensa || true
