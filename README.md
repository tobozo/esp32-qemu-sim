# ESP32 QEmu Runner

Use `tobozo/esp32-quemu-sim` github action to run an esp32 compiled binary in [QEmu](https://github.com/espressif/qemu) and capture the serial output.


```yaml
  - name: 'ESP32 QEmu Runner'
  - uses: tobozo/esp32-quemu-sim@v1
    with:
      flash-size: 4
      build-folder: ./build
```


## Options


### Flash Size

Specify a different flash size, valid values are 2, 4, 8, 16

```yaml
  with:
    flash-size: 4
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
    partitions-csv: my_partitions.csv # relative to build-folder
    otadata-bin: my_boot_app0.bin # relative to build-folder
    firmware-bin: my_firmware.bin # relative to build-folder, default=firmware.bin
    partitions-bin: my_partitions.bin # relative to build-folder, default=partitions.bins
    bootloader-bin: my_bootloader.bin # relative to build-folder, default=bootloader.bin
    spiffs-bin: my_spiffs.bin # relative to build-folder
```


### Bootloader Address

[Experimental] Optionally change the addresses for bootloader.bin and partitions.bin.
The other addresses are extracted form the partitions.csv file.

```yaml
  with:
    bootloader-address: "0x1000"
    partitions-address: "0x8000"
```


### Complete Workflow Example


```yaml


on: [push]

jobs:
  hello_world_job:

    runs-on: ubuntu-latest
    name: A job to say hello

    env:
      SKETCH_REPO: tobozo/esp32-quemu-sim # put your ESP32 project repo here
      SKETCH_NAME: HelloWorld.ino

    steps:

      - name: Checkout
        uses: actions/checkout@v3
        with:
          repository: ${{ env.SKETCH_REPO }} # pull the examples/HelloWorld/HelloWorld.ino from your repo
          ref: ${{ github.event.pull_request.head.sha }}

      - name: Compile sketch
        uses: ArminJo/arduino-test-compile@v3.2.0
        with:
          platform-url: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_dev_index.json
          arduino-board-fqbn: esp32:esp32:esp32:FlashMode=dio,FlashFreq=80,FlashSize=4M
          arduino-platform: esp32:esp32@2.0.7
          # extra-arduino-lib-install-args: --no-deps
          # extra-arduino-cli-args: "--warnings default " # see https://github.com/ArminJo/arduino-test-compile/issues/28
          sketch-names: ${{ env.SKETCH_NAME }}
          set-build-path: true # build in the sketch folder

      - uses: tobozo/esp32-quemu-sim@main
        with:
          build-folder: examples/HelloWorld/build
          partitions-csv: partitions.csv
          firmware-bin: HelloWorld.ino.bin
          bootloader-bin: HelloWorld.ino.bootloader.bin
          partitions-bin: HelloWorld.ino.partitions.bin
          spiffs-bin: HelloWorld.ino.spiffs.bin

```

## Roadmap:

- GDB
- Custom strapping mode
- eFuse (storage, secure boot)
- Watchdogs




## Credits:

- https://github.com/espressif/qemu
- https://github.com/listout (fixed flash sizes in QEmu)
