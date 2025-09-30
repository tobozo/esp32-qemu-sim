# ESP32 QEmu Runner

Use `tobozo/esp32-qemu-sim` github action to run an esp32 compiled binary in [QEmu](https://github.com/espressif/qemu) and capture the serial output.


```yaml
  - name: 'ESP32 QEmu Runner'
  - uses: tobozo/esp32-qemu-sim@v1
    with:
      chip: esp32c3
      flash-image: Sketch/build/Sketch.ino.merged.bin
```

:warning: when `flash-image` is set, all flash options are ignored.


## Requirements

- FlashMode must be DIO/80MHz, qemu doesn't like QIO


## Options


### Chip name

Supported chips are: `esp32`, `esp32s3`, `esp32c3`.

```yaml
  with:
    chip: esp32c3
```

### QEmu timeout

Specify how long the action will sleep after launching QEmu.
All QEmu output + ESP32 console output will be logged during this delay.
QEmu will be killed after that to prevent it from running indefinitely.
The logs will be available as an artifact once the action is complete.

```yaml
  with:
    qemu-timeout: "60"
```

A timeout can be interrupted when Qemu output matches a given string or regex.

```yaml
  with:
    qemu-timeout: "1200" # 20 minutes
    timeout-interrupt-regex: "Test Complete"
    # timeout-interrupt-regex: "/^Test Complete$/"
    # timeout-interrupt-regex: "/(Test Complete)|(guru meditation)/"
```


### Device Options

```yaml
  with:
    psram: 2M
```

Valid psram size values are `(none)`, `2M`, `4M`, `8M`, `16M`, `32M`.


## Flash Options

When `flash-image` input is not set, esp32-qemu-sim can take care of merging the binary with esptool.
Alternatively if `flash-image` is set, all subsequent inputs will be ignored.


### Project Build Folder

/!\ The ESP32 build folder must be set and populated in the workflow prior to calling the action.
The default path to the ESP32 project binaries is `./build`, but your mileage may vary:


```yaml
  with:
    build-folder: ./my-build-folder
```

## Flash Size

Specify a different flash size and/or psram size.

Valid flash size values are `2`, `4`, `8`, `16`.


```yaml
  with:
    flash-size: 4
```


### Project Build Folder

/!\ The ESP32 build folder must be set and populated in the workflow prior to calling the action.
The default path to the ESP32 project binaries is `./build`, but your mileage may vary:


```yaml
  with:
    build-folder: ./my-build-folder
```

The `build-folder` can point to the ESP32 project build folder, but only those files are needed by QEmu to build a flash image:

- partitions.csv
- partitions.bin
- bootloader.bin
- boot_app0.bin
- firmware.bin
- spiffs.bin (optional)

Note: the default file names can be overriden, but should always reside in the `build-folder`.

```yaml
  with:
    build-folder: ./my-build-folder
    partitions-csv: my_partitions.csv # relative to build-folder
    otadata-bin: my_boot_app0.bin # relative to build-folder
    firmware-bin: my_firmware.bin # relative to build-folder, default=firmware.bin
    partitions-bin: my_partitions.bin # relative to build-folder, default=partitions.bins
    bootloader-bin: my_bootloader.bin # relative to build-folder, default=bootloader.bin
    spiffs-bin: my_spiffs.bin # relative to build-folder
```


### Partitions Address

[Experimental] Optionally change the address for partitions.bin.
The other addresses are extracted form the partitions.csv file or guessed from the chip name

```yaml
  with:
    partitions-address: "0x8000"
```


### Complete Workflow Example


```yaml
on: [push]

jobs:
  hello_world_job:

    runs-on: ubuntu-latest
    name: A job to say hello

    steps:

      - name: Checkout ESP32 project
        uses: actions/checkout@v3
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          # repository: user/repository # or set the ESP32 project manually if different from the runner

      # use Arminjo's github action to compile a sketch (could also be esp-idf or plaformio)
      - name: Compile ESP32 project
        uses: ArminJo/arduino-test-compile@v3.2.0
        with:
          platform-url: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_dev_index.json
          arduino-board-fqbn: esp32:esp32:esp32:FlashMode=dio,FlashFreq=80,FlashSize=4M
          arduino-platform: esp32:esp32@3.3.1
          sketch-names: HelloWorld.ino # Will build "HelloWorld.ino"
          set-build-path: true # build in the sketch folder
          # extra-arduino-lib-install-args: --no-deps
          # extra-arduino-cli-args: "--warnings default " # see https://github.com/ArminJo/arduino-test-compile/issues/28

      - name: Run ESP32 project in QEmu
        uses: tobozo/esp32-qemu-sim@main
        with:
          chip: esp32 
          ## Set the build folder and file names for esp32-qemu-sim
          flash-image: examples/HelloWorld/build/HelloWorld.ino.merged.bin
          ## OR set the flash image elements separately
          # build-folder: examples/HelloWorld/build
          # partitions-csv: partitions.csv
          # firmware-bin: HelloWorld.ino.bin
          # bootloader-bin: HelloWorld.ino.bootloader.bin
          # partitions-bin: HelloWorld.ino.partitions.bin
          # spiffs-bin: HelloWorld.ino.spiffs.bin
```

## Roadmap:

- GDB
- Custom strapping mode
- eFuse (storage, secure boot)
- Watchdogs



## Credits:

- https://github.com/espressif/qemu
- https://github.com/listout (fixed flash sizes in QEmu)
- https://github.com/Roms1383 (peer contributor)
