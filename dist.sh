#!/bin/bash

if [ -z "${ANDROID_SDK}" ]; then
  echo "Specify the Android SDK directory through the ANDROID_SDK environment variable"
  exit 1
fi

NDK_VERSION="23.1.7779620"
NDK_PATH="${ANDROID_SDK}/ndk/${NDK_VERSION}"

if [ ! -d "${NDK_PATH}" ]; then
  echo "NDK version ${NDK_VERSION} is required and was not found at ${NDK_PATH}"
  exit 1
fi

NDK_BUILD="${NDK_PATH}/ndk-build"

(cd ./zygisk_module && ${NDK_BUILD}) || exit 1

mkdir ./module/zygisk

for i in $(ls ./zygisk_module/libs); do
  cp -f ./zygisk_module/libs/$i/*.so ./module/zygisk/$i.so
done

UPDATE_BINARY_URL="https://raw.githubusercontent.com/topjohnwu/Magisk/master/scripts/module_installer.sh"

mkdir -p ./module/META-INF/com/google/android
curl "${UPDATE_BINARY_URL}" > ./module/META-INF/com/google/android/update-binary
echo "#MAGISK" > ./module/META-INF/com/google/android/updater-script

VERSION=$(sed -ne "s/version=\(.*\)/\1/gp" ./module/module.prop)
NAME=$(sed -ne "s/id=\(.*\)/\1/gp" ./module/module.prop)

rm -f ${NAME}-${VERSION}.zip
(
  cd ./module
  zip ../${NAME}-${VERSION}.zip -r * -x ".*" "*/.*"
)
