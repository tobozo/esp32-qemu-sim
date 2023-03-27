#!/bin/bash

# TODO: validate/sanitize/restrict build-folder path
if [[ "$ENV_BUILD_FOLDER" == "" ]]; then
  echo "[ERROR] No build folder provided"
  exit 1
fi

if [[ ! -d "$ENV_BUILD_FOLDER" ]]; then
  echo "[ERROR] No build folder found, aborting"
  exit 1
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV" ]]; then
  echo "[ERROR] Missing partitions.csv file in build folder"
  exit 1
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_OTADATA_BIN" ]]; then
  echo "[INFO] Fetching a copy of boot_app0.bin from espressif/arduino-esp32 repository"
  wget -q https://github.com/espressif/arduino-esp32/raw/master/tools/partitions/boot_app0.bin -O "$ENV_BUILD_FOLDER/$ENV_OTADATA_BIN"
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_FIRMWARE_BIN" ]]; then
  echo "[ERROR] Missing app0, check your 'firmware-bin' path"
  exit 1
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_PARTITIONS_BIN" ]]; then
  # TODO: generate partitions.bin from partitions.csv using gen_esp32part.py
  echo "[ERROR] Missing partitions.bin, check your 'partitions-bin' path"
  exit 1
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_BOOTLOADER_BIN" ]]; then
  echo "[ERROR] Missing bootloader.bin, check your 'bootloader-bin' path"
  exit 1
fi

if [[ ! -f "$ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN" ]]; then
  echo "[INFO] Creating empty SPIFFS file"
  touch "$ENV_BUILD_FOLDER/$ENV_SPIFFS_BIN"
fi

if [[ "$ENV_FLASH_SIZE" =~ '^(2|4|8|16)$' ]]; then
  echo "[ERROR] Invalid flash size (valid values=2,4,8,16)"
  exit 1
fi

if [[ "$ENV_QEMU_TIMEOUT" =~ '^[0-9]{1,3}$' ]]; then
  echo "[ERROR] Invalid timeout value (valid values=0...999)"
  exit 1
fi

if [[ "$ENV_FLASH_SIZE" == "" ]]; then
  echo "[ERROR] Missing flash size property"
  exit 1
fi

if [[ "$ENV_QEMU_TIMEOUT" == "" ]]; then
  echo "[ERROR] Missing timeout property"
  exit 1
fi

if [[ "$ENV_BOOTLOADER_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi
if [[ "$ENV_PARTITIONS_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi
if [[ "$ENV_PARTITIONS_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi

cat $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV
OLD_IFS=$IFS
csvdata=`cat $ENV_BUILD_FOLDER/$ENV_PARTITIONS_CSV | tr -d ' ' | tr '\n' ';'` # remove spaces, replace \n by semicolon
IFS=';' read -ra rows <<< "$csvdata" # split lines
for index in "${!rows[@]}"
do
  IFS=',' read -ra csv_columns <<< "${rows[$index]}" # split columns
  case "${csv_columns[0]}" in
    otadata)  OTADATA_ADDR="${csv_columns[3]}" ;;
    app0)     FIRMWARE_ADDR="${csv_columns[3]}"  ;;
    spiffs)   SPIFFS_ADDR="${csv_columns[3]}"    ;;
    *) echo "Ignoring ${csv_columns[0]}:${csv_columns[3]}" ;;
  esac
done
( set -o posix ; set ) | grep _ADDR
IFS=$OLD_IFS

if [[ "$OTADATA_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid otadata address in $ENV_PARTITIONS_CSV file"
  exit 1
fi

if [[ "$FIRMWARE_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid app0 address in $ENV_PARTITIONS_CSV file"
  exit 1
fi

if [[ "$SPIFFS_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[WARNING] Invalid or empty spiffs address extracted from $ENV_PARTITIONS_CSV file, overriding"
  $SPIFFS_ADDR="0x290000"
fi

#echo "OTADATA_ADDR=$OTADATA_ADDR" >> $GITHUB_ENV
#echo "FIRMWARE_ADDR=$FIRMWARE_ADDR" >> $GITHUB_ENV
#echo "SPIFFS_ADDR=$SPIFFS_ADDR" >> $GITHUB_ENV

echo "[INFO] Building flash image for QEmu"

./esptool/esptool.py --chip esp32 merge_bin --fill-flash-size ${ENV_FLASH_SIZE}MB -o flash_image.bin \
  $ENV_BOOTLOADER_ADDR $ENV_BOOTLOADER_BIN \
  $ENV_PARTITIONS_ADDR $ENV_PARTITIONS_BIN \
  $OTADATA_ADDR $ENV_OTADATA_BIN \
  $FIRMWARE_ADDR $ENV_FIRMWARE_BIN \
  $SPIFFS_ADDR $SPIFFS_BIN

echo "[INFO] Running flash in QEmu for $ENV_QEMU_TIMEOUT seconds"

(./qemu-git/build/qemu-system-xtensa -nographic -machine esp32 -drive file=flash_image.bin,if=mtd,format=raw | tee -a ./logs.txt) &
sleep $ENV_QEMU_TIMEOUT
killall qemu-system-xtensa || true
