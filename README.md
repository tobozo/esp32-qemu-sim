# esp32-quemu-sim

Github Action to test an esp32 compiled binary in [QEmu](https://github.com/espressif/qemu).


```yaml
      - uses: tobozo/esp32-quemu-sim@main
        with:
          flash-size: 4 #MB
          qemu-timeout: 60 #seconds to wait before killing qemu
          build-folder: ./build # where the binaries and partitions.csv files can be found
```



The build folder must be available to the parent workflow prior to calling this action.






```yaml


on: [push]

jobs:
  hello_world_job:
    runs-on: ubuntu-latest
    name: A job to say hello
    steps:

      - name: Checkout
        uses: actions/checkout@v3
        with:
          repository: tobozo/esp32-quemu-sim
          ref: ${{ github.event.pull_request.head.sha }}

      - name: Compile sketch
        uses: ArminJo/arduino-test-compile@v3.2.0
        with:
          platform-url: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_dev_index.json
          arduino-board-fqbn: esp32:esp32:esp32:FlashMode=dio,FlashFreq=80,FlashSize=4M
          arduino-platform: esp32:esp32@2.0.7
          extra-arduino-lib-install-args: --no-deps
          extra-arduino-cli-args: "--warnings default " # see https://github.com/ArminJo/arduino-test-compile/issues/28
          sketch-names: HelloWorld.ino
          set-build-path: true
      - name: Copy compiled binaries
        run: |
          cp -R examples/HelloWorld/build ./build
          ls ./build/*.bin -la
          # normalize file names
          mv ./build/HelloWorld.ino.bin ./build/firmware.bin
          mv ./build/HelloWorld.ino.bootloader.bin ./build/bootloader.bin
          mv ./build/HelloWorld.ino.partitions.bin ./build/partitions.bin
          if [[ -f "./build/HelloWorld.ino.spiffs.bin" ]]; then
            mv ./build/HelloWorld.ino.spiffs.bin ./build/spiffs.bin
          fi

      - uses: tobozo/esp32-quemu-sim@main
        with:
          flash-size: 4 #MB
          qemu-timeout: 60 #seconds
          build-folder: ./build # where


```


Credits:

- https://github.com/espressif/qemu
