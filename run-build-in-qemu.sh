#!/bin/bash

# run-build-in-qemu.sh
# Bash script to a run an esp32 compiled binary in QEmu and capture the outptut
#
# Copyright (C) 2023 tobozo
# https://github.com/tobozo/
# License: MIT
#



ESPTOOL="./esptool/esptool.py"
QEMU_XTENSA_BIN="./qemu-git/build/qemu-system-xtensa"
QEMU_RISCV_BIN="./qemu-git/build/qemu-system-riscv64"


if [[ "$ENV_DEBUG" != "false" ]]; then
  function _debug { echo "[$(date +%H:%M:%S)][DEBUG] $1"; }
else
  function _debug { return; }
fi

function exit_with_error { echo "$1"; exit 1; }

echo "[INFO] Validating target chip"

# TODO query `$QEMU_BIN -machine ? | grep esp32` and compare
[[ "$ENV_CHIP" =~ ^esp32(c3|s3)?$ ]] || exit_with_error "Invalid chip name, valid names are: esp32, esp32c3, esp32s3"

case "$ENV_CHIP" in
    "esp32")
        QEMU_BIN=$QEMU_XTENSA_BIN
        ENV_BOOTLOADER_ADDR=0x1000
        ;;
    "esp32s3")
        QEMU_BIN=$QEMU_XTENSA_BIN
        ENV_BOOTLOADER_ADDR=0x0
        ;;
    "esp32c3")
        QEMU_BIN=$QEMU_RISCV_BIN
        ENV_BOOTLOADER_ADDR=0x0
        ;;
    *)
        exit_with_error "Unknown Chip $ENV_CHIP"
        ;;
esac

echo "[INFO] Validating tools"

[[ ! -f "$QEMU_BIN" ]] && exit_with_error "qemu binary is missing for $ENV_CHIP"
[[ ! -f "$ESPTOOL" ]] && exit_with_error "esptool is missing at path: $ESPTOOL"


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
#[[ "$ENV_PSRAM" =~ ^(2M|4M)$ ]] && exit_with_error "Invalid psram size (valid values=2,4,8,16)"
[[ "$ENV_PSRAM" =~ ^(2M|4M)$ ]] && ENV_PSRAM="-m $ENV_PSRAM" || ENV_PSRAM=""
[[ "$ENV_QEMU_TIMEOUT" =~ ^[0-9]{1,3}$ ]] || exit_with_error "Invalid timeout value (valid values=0...999)"
[[ "$ENV_BOOTLOADER_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]] || exit_with_error "Invalid bootloader address '$ENV_BOOTLOADER_ADDR' (valid values=0x0000...0xffffffff)"
[[ "$ENV_PARTITIONS_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]] || exit_with_error "Invalid partitions address '$ENV_PARTITIONS_ADDR' (valid values=0x0000...0xffffffff)"
#[[ "$ENV_PARTITIONS_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]] || exit_with_error "Invalid bootloader address (valid values=0x0000...0xffffffff)"

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

[[ "$OTADATA_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]] || exit_with_error "Invalid otadata address in $ENV_PARTITIONS_CSV file"
[[ "$FIRMWARE_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]] || exit_with_error "Invalid app0 address in $ENV_PARTITIONS_CSV file"


if [[ ! "$SPIFFS_ADDR" =~ ^0x[0-9a-zA-Z]{1,8}$ ]]; then
  echo "[WARNING] Invalid or empty spiffs address extracted from $ENV_PARTITIONS_CSV file :$SPIFFS_ADDR, overriding"
  SPIFFS_ADDR="0x290000"
fi

if [[ "$SPIFFS_ADDR" != "$ENV_SPIFFS_ADDR" ]]; then
  echo "[WARNING] SPIFFS address mismatch (csv=$SPIFFS_ADDR, workflow=$ENV_SPIFFS_ADDR)"
fi


echo "[INFO] Building flash image for QEmu"

_debug "Flash Size:   $ENV_FLASH_SIZE"
_debug "Build Folder: $ENV_BUILD_FOLDER"
_debug "Partitions csv file: $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV"
_debug "`cat $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV`"
_debug "$ESPTOOL --chip $ENV_CHIP merge-bin --pad-to-size ${ENV_FLASH_SIZE}MB -o flash_image.bin $ENV_BOOTLOADER_ADDR $ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN $ENV_PARTITIONS_ADDR $ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN $OTADATA_ADDR $ENV_BUILD_FOLDER/$ENV_OTADATA_BIN $FIRMWARE_ADDR $ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN $SPIFFS_ADDR $ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN"

$ESPTOOL --chip $ENV_CHIP merge-bin --fill-flash-size ${ENV_FLASH_SIZE}MB -o flash_image.bin \
  $ENV_BOOTLOADER_ADDR $ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN \
  $ENV_PARTITIONS_ADDR $ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN \
  $OTADATA_ADDR $ENV_BUILD_FOLDER/$ENV_OTADATA_BIN \
  $FIRMWARE_ADDR $ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN \
  $SPIFFS_ADDR $ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN


echo "[INFO] Running flash image in QEmu"
_debug "QEmu timeout: $ENV_QEMU_TIMEOUT seconds"
_debug "$QEMU_BIN -nographic -machine $ENV_CHIP $ENV_PSRAM -drive file=flash_image.bin,if=mtd,format=raw -global driver=timer.$ENV_CHIP.timg,property=wdt_disable,value=true"

log_file=./logs.txt

($QEMU_BIN -nographic -machine $ENV_CHIP $ENV_PSRAM -drive file=flash_image.bin,if=mtd,format=raw -global driver=timer.$ENV_CHIP.timg,property=wdt_disable,value=true | tee -a $log_file) &


if [[ "$ENV_TIMEOUT_INT_RE" != "" ]]; then

  _debug "Timing out in $ENV_QEMU_TIMEOUT seconds unless output matches '$ENV_TIMEOUT_INT_RE'"

  timeout=$ENV_QEMU_TIMEOUT
  interval=1

  while ((timeout > 0)); do
    sleep $interval
    grep_result=`tail ${log_file} | grep "${ENV_TIMEOUT_INT_RE}"`
    if [[ "$grep_result" =~ $ENV_TIMEOUT_INT_RE ]]; then
      _debug "[INFO] Got interrupt signal from esp32 $timeout seconds before timeout";
      break
    fi
    ((timeout -= interval))
  done

else

  _debug "Timing out in $ENV_QEMU_TIMEOUT seconds"

  sleep $ENV_QEMU_TIMEOUT

fi

killall qemu-system-xtensa || true
