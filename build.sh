#!/bin/bash

# Compile script for ThunderBolt kernel
# Copyright (C) 2022-2023 Amritorock.

# Initializing variables
SECONDS=0 # builtin bash timer
ZIPNAME="ThunderBolt-r5x-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$HOME/tc/xRageTC-clang"
AK3_DIR="$HOME/android/AnyKernel3"
DEFCONFIG="vendor/RMX1911_defconfig"

#Telegram Updatation
send_telegram_message(){
     curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
     -d chat_id="$chat_id" \
     -d "text=$1"
}

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
 ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"

if ! [ -d "$TC_DIR" ]; then
  echo "xRageTC-clang not found! Cloning to $TC_DIR..."
if ! git clone -q -b main --depth=1 https://github.com/xyz-prjkt/xRageTC-clang $TC_DIR; then
  echo "Cloning failed! Aborting..."
  exit 1
fi
fi

export KBUILD_BUILD_USER=Amrito
export KBUILD_BUILD_HOST=Stable_Builds

if [[ $1 = "-r" || $1 = "--regen" ]]; then
  make O=out ARCH=arm64 $DEFCONFIG savedefconfig
  cp out/defconfig arch/arm64/configs/$DEFCONFIG
  exit
fi

if [[ $1 = "-c" || $1 = "--clean" ]]; then
  rm -rf out
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

#Notify compilation start
send_telegram_message "Starting compilation..."
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
  if [ -d "$AK3_DIR" ]; then
    cp -r $AK3_DIR AnyKernel3
  elif ! git clone -q https://github.com/Amritorock/AnyKernel3; then
    echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
    exit 1
  fi
  cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
  cp out/arch/arm64/boot/dtbo.img AnyKernel3
  rm -f *zip
  cd AnyKernel3
  git checkout master &> /dev/null
  zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
  cd ..
  rm -rf AnyKernel3
  rm -rf out/arch/arm64/boot

  # Upload the ZIP file to telegram
  compilation_successfull="Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
  curl -F chat_id="$chat_id" -F document=@"$ZIPNAME" -F caption="$compilation_successfull" "https://api.telegram.org/bot$token/sendDocument"

else
  send_telegram_message "Compilation failed!"
  exit 1
fi