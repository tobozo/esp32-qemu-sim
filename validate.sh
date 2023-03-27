#!/bin/bash

# TODO: validate/sanitize/restrict build-folder path
if [[ "${{ inputs.build-folder }}" == "" ]]; then
  echo "[ERROR] No build folder provided"
  exit 1
fi

if [[ ! -d "${{ inputs.build-folder }}" ]]; then
  echo "[ERROR] No build folder found, aborting"
  exit 1
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.partitions-csv }}" ]]; then
  echo "[ERROR] Missing partitions.csv file in build folder"
  exit 1
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.otadata-bin }}" ]]; then
  echo "[INFO] Fetching a copy of boot_app0.bin from espressif/arduino-esp32 repository"
  wget -q https://github.com/espressif/arduino-esp32/raw/master/tools/partitions/boot_app0.bin -O "${{ inputs.build-folder }}/${{ inputs.otadata-bin }}"
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.firmware-bin }}" ]]; then
  echo "[ERROR] Missing app0, check your 'firmware-bin' path"
  exit 1
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.partitions-bin }}" ]]; then
  # TODO: generate partitions.bin from partitions.csv using gen_esp32part.py
  echo "[ERROR] Missing partitions.bin, check your 'partitions-bin' path
  exit 1
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.bootloader-bin }}" ]]; then
  echo "[ERROR] Missing bootloader.bin, check your 'bootloader-bin' path
  exit 1
fi

if [[ ! -f "${{ inputs.build-folder }}/${{ inputs.spiffs-bin }}" ]]; then
  echo "[INFO] Creating empty SPIFFS file"
  touch "${{ inputs.build-folder }}/${{ inputs.spiffs-bin }}"
fi

if [[ "${{ inputs.flash-size }}" =~ '^(2|4|8|16)$' ]]; then
  echo "[ERROR] Invalid flash size (valid values=2,4,8,16)"
  exit 1
fi

if [[ "${{ inputs.qemu-timeout }}" =~ '^[0-9]{1,3}$' ]]; then
  echo "[ERROR] Invalid timeout value (valid values=0...999)"
  exit 1
fi

if [[ "${{ inputs.flash-size }}" == "" ]]; then
  echo "[ERROR] Missing flash size property"
  exit 1
fi

if [[ "${{ inputs.qemu-timeout }}" == "" ]]; then
  echo "[ERROR] Missing timeout property"
  exit 1
fi

if [[ "${{ inputs.bootloader-address }}" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi
if [[ "${{ inputs.partitions-address }}" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi
if [[ "${{ inputs.partitions-address }}" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid bootloader address (valid values=0x0000...0xffffffff)"
  exit 1
fi

cat ${{ inputs.build-folder }}/${{ inputs.partitions-csv }}
OLD_IFS=$IFS
csvdata=`cat ${{ inputs.build-folder }}/${{ inputs.partitions-csv }} | tr -d ' ' | tr '\n' ';'` # remove spaces, replace \n by semicolon
IFS=';' read -ra rows <<< "$csvdata" # split lines
for index in "${!rows[@]}"
do
  IFS=',' read -ra csv_columns <<< "${rows[$index]}" # split columns
  case "${csv_columns[0]}" in
    otadata)  BOOT_APP0_ADDR="${csv_columns[3]}" ;;
    app0)     FIRMWARE_ADDR="${csv_columns[3]}"  ;;
    spiffs)   SPIFFS_ADDR="${csv_columns[3]}"    ;;
    *) echo "Ignoring ${csv_columns[0]}:${csv_columns[3]}" ;;
  esac
done
( set -o posix ; set ) | grep _ADDR
IFS=$OLD_IFS

if [[ "$BOOT_APP0_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid otadata address in ${{ inputs.partitions-csv }} file"
  exit 1
fi

if [[ "$FIRMWARE_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[ERROR] Invalid app0 address in ${{ inputs.partitions-csv }} file"
  exit 1
fi

if [[ "$SPIFFS_ADDR" =~ '^0x[0-9a-z-A-Z]{1,8}$' ]]; then
  echo "[WARNING] Invalid or empty spiffs address extracted from ${{ inputs.partitions-csv }} file, overriding"
  $SPIFFS_ADDR="0x290000"
fi

echo "BOOT_APP0_ADDR=$BOOT_APP0_ADDR" >> $GITHUB_ENV
echo "FIRMWARE_ADDR=$FIRMWARE_ADDR" >> $GITHUB_ENV
echo "SPIFFS_ADDR=$SPIFFS_ADDR" >> $GITHUB_ENV
