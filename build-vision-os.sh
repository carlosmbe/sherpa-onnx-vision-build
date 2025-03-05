#!/usr/bin/env  bash

set -e

dir=build-vision-os
mkdir -p $dir
cd $dir
onnxruntime_version=1.20.2
onnxruntime_xros_arm64=onnxruntime-vision_os-xros_arm64-$onnxruntime_version/onnxruntime.framework

SHERPA_ONNX_HF=huggingface.co

if [ "$SHERPA_ONNX_HF_MIRROW" == true ]; then
    SHERPA_ONNX_HF=hf-mirror.com
fi

if [ ! -f $onnxruntime_xros_arm64/libonnxruntime.dylib ]; then
  wget -c https://$SHERPA_ONNX_HF/csukuangfj/onnxruntime-libs/resolve/main/onnxruntime-vision_os-xros_arm64-$onnxruntime_version.zip
  unzip onnxruntime-vision_os-xros_arm64-$onnxruntime_version.zip
  rm onnxruntime-vision_os-xros_arm64-$onnxruntime_version.zip
fi

# First, for simulator
echo "Building for visionOS (arm64)"

export SHERPA_ONNXRUNTIME_LIB_DIR=$PWD/$onnxruntime_xros_arm64
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=$PWD/$onnxruntime_xros_arm64/Headers

echo "SHERPA_ONNXRUNTIME_LIB_DIR: $SHERPA_ONNXRUNTIME_LIB_DIR"
echo "SHERPA_ONNXRUNTIME_INCLUDE_DIR $SHERPA_ONNXRUNTIME_INCLUDE_DIR"
cmake \
  -DBUILD_PIPER_PHONMIZE_EXE=OFF \
  -DBUILD_PIPER_PHONMIZE_TESTS=OFF \
  -DBUILD_ESPEAK_NG_EXE=OFF \
  -DBUILD_ESPEAK_NG_TESTS=OFF \
  -S .. \
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake \
  -DPLATFORM=VISIONOS \
  -DENABLE_BITCODE=0 \
  -DENABLE_ARC=1 \
  -DENABLE_VISIBILITY=0 \
  -DCMAKE_BUILD_TYPE=Debug \
  -DBUILD_SHARED_LIBS=ON \
  -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
  -DSHERPA_ONNX_ENABLE_TESTS=OFF \
  -DSHERPA_ONNX_ENABLE_CHECK=OFF \
  -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
  -DSHERPA_ONNX_ENABLE_JNI=OFF \
  -DSHERPA_ONNX_ENABLE_C_API=ON \
  -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
  -DCMAKE_INSTALL_PREFIX=./install \
  -DDEPLOYMENT_TARGET=13.0 \
  -B build/vision_os_arm64
  

cmake --build build/vision_os_arm64 -j 4 --verbose

cmake --build build/vision_os_arm64 --target install

echo "Generate xcframework"

rm -rf sherpa-onnx.xcframework

echo "Doing Static Library"

libtool -static -o build/vision_os_arm64/lib/libsherpa-onnx.a \
  build/vision_os_arm64/lib/libsherpa-onnx-core.a \
  build/vision_os_arm64/lib/libkaldi-native-fbank-core.a \
  build/vision_os_arm64/lib/libsherpa-onnx-fstfar.a \
  build/vision_os_arm64/lib/libsherpa-onnx-fst.a \
  build/vision_os_arm64/lib/libsherpa-onnx-kaldifst-core.a \
  build/vision_os_arm64/lib/libkaldi-decoder-core.a \
  build/vision_os_arm64/lib/libucd.a \
  build/vision_os_arm64/lib/libpiper_phonemize.a \
  build/vision_os_arm64/lib/libespeak-ng.a \
  build/vision_os_arm64/lib/libssentencepiece_core.a

echo "Converting Dynamic Libraries into frameworks"

# Create a folder for vision-arm64 frameworks
mkdir -p vision-arm64

# -----------------------------
# Package libsherpa-onnx-c-api.dylib as sherpa_onnx.framework
# -----------------------------
cp -v build/vision_os_arm64/lib/libsherpa-onnx-c-api.dylib vision-arm64/

pushd vision-arm64
rm -rf sherpa_onnx.framework
mkdir sherpa_onnx.framework
cp libsherpa-onnx-c-api.dylib sherpa_onnx.framework/sherpa_onnx
install_name_tool -change @rpath/libsherpa-onnx-c-api.dylib @rpath/sherpa_onnx.framework/sherpa_onnx sherpa_onnx.framework/sherpa_onnx
install_name_tool -id "@rpath/sherpa_onnx.framework/sherpa_onnx" sherpa_onnx.framework/sherpa_onnx
chmod +x sherpa_onnx.framework/sherpa_onnx
popd

# -----------------------------
# Package libcargs.dylib as cargs.framework
# -----------------------------
cp -v build/vision_os_arm64/lib/libcargs.dylib vision-arm64/

pushd vision-arm64
rm -rf cargs.framework
mkdir cargs.framework
cp libcargs.dylib cargs.framework/cargs
install_name_tool -change @rpath/libcargs.dylib @rpath/cargs.framework/cargs cargs.framework/cargs
install_name_tool -id "@rpath/cargs.framework/cargs" cargs.framework/cargs
chmod +x cargs.framework/cargs
popd

# -----------------------------
# Package libsherpa-onnx-cxx-api.dylib as sherpa_onnx_cxx_api.framework
# -----------------------------
cp -v build/vision_os_arm64/lib/libsherpa-onnx-cxx-api.dylib vision-arm64/

pushd vision-arm64
rm -rf sherpa_onnx_cxx_api.framework
mkdir sherpa_onnx_cxx_api.framework
cp libsherpa-onnx-cxx-api.dylib sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
install_name_tool -change @rpath/libsherpa-onnx-cxx-api.dylib @rpath/sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
install_name_tool -id "@rpath/sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api" sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
chmod +x sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
popd


echo "Xcode Build XCFramework"
rm -rf sherpa-onnx.xcframework

xcodebuild -create-xcframework \
  -library build/vision_os_arm64/lib/libsherpa-onnx.a \
  -headers ./install/include \
  -output sherpa-onnx.xcframework

echo "Done xcframework"
echo "Remember to add the dynamic library .framework files in vision-arm64"