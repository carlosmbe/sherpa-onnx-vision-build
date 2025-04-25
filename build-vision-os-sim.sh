#!/usr/bin/env bash

set -e

# Function to generate minimal Info.plist for frameworks
generate_info_plist() {
  framework_name=$1
  version=$2
  min_os_version=$3

  plist_path="$framework_name.framework/Resources/Info.plist"
  
  mkdir -p "$framework_name.framework/Resources"
  
  cat <<EOF > "$plist_path"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.yourcompany.$framework_name</string>
  <key>CFBundleVersion</key>
  <string>$version</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleExecutable</key>
  <string>$framework_name</string>
  <key>MinimumOSVersion</key>
  <string>$min_os_version</string>
</dict>
</plist>
EOF
}

dir=build-vision-os
mkdir -p $dir
cd $dir
onnxruntime_version=1.20.0
onnxruntime_xrsimulator_arm64=onnxruntime-vision_os-xrsimulator_arm64-$onnxruntime_version/onnxruntime.framework

SHERPA_ONNX_HF=huggingface.co

if [ "$SHERPA_ONNX_HF_MIRROW" == true ]; then
    SHERPA_ONNX_HF=hf-mirror.com
fi

if [ ! -f $onnxruntime_xrsimulator_arm64/libonnxruntime.dylib ]; then
  wget -c https://$SHERPA_ONNX_HF/csukuangfj/onnxruntime-libs/resolve/main/onnxruntime-vision_os-xrsimulator_arm64-1.20.0.zip
  unzip onnxruntime-vision_os-xrsimulator_arm64-1.20.0.zip
  rm onnxruntime-vision_os-xrsimulator_arm64-1.20.0.zip
fi

# First, for simulator
echo "Building for visionOS (arm64)"

export SHERPA_ONNXRUNTIME_LIB_DIR=$PWD/$onnxruntime_xrsimulator_arm64
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=$PWD/$onnxruntime_xrsimulator_arm64/Headers

echo "SHERPA_ONNXRUNTIME_LIB_DIR: $SHERPA_ONNXRUNTIME_LIB_DIR"
echo "SHERPA_ONNXRUNTIME_INCLUDE_DIR $SHERPA_ONNXRUNTIME_INCLUDE_DIR"
cmake \
  -DBUILD_PIPER_PHONMIZE_EXE=OFF \
  -DBUILD_PIPER_PHONMIZE_TESTS=OFF \
  -DBUILD_ESPEAK_NG_EXE=OFF \
  -DBUILD_ESPEAK_NG_TESTS=OFF \
  -S .. \
  -DCMAKE_TOOLCHAIN_FILE=./toolchains/ios.toolchain.cmake \
  -DPLATFORM=SIMULATOR_VISIONOS \
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
  -DDEPLOYMENT_TARGET=1.0 \
  -B build/vision_os_sim
  

cmake --build build/vision_os_sim -j 4 --verbose

cmake --build build/vision_os_sim --target install

echo "Generate xcframework"

rm -rf sherpa-onnx.xcframework

echo "Doing Static Library"

libtool -static -o build/vision_os_sim/lib/libsherpa-onnx.a \
  build/vision_os_sim/lib/libsherpa-onnx-core.a \
  build/vision_os_sim/lib/libkaldi-native-fbank-core.a \
  build/vision_os_sim/lib/libsherpa-onnx-fstfar.a \
  build/vision_os_sim/lib/libsherpa-onnx-fst.a \
  build/vision_os_sim/lib/libsherpa-onnx-kaldifst-core.a \
  build/vision_os_sim/lib/libkaldi-decoder-core.a \
  build/vision_os_sim/lib/libucd.a \
  build/vision_os_sim/lib/libpiper_phonemize.a \
  build/vision_os_sim/lib/libespeak-ng.a \
  build/vision_os_sim/lib/libssentencepiece_core.a

echo "Converting Dynamic Libraries into frameworks"

# Create a folder for vision-sim frameworks
mkdir -p vision-sim

# -----------------------------
# Package libsherpa-onnx-c-api.dylib as sherpa_onnx.framework
# -----------------------------
cp -v build/vision_os_sim/lib/libsherpa-onnx-c-api.dylib vision-sim/

pushd vision-sim
rm -rf sherpa_onnx.framework
mkdir -p sherpa_onnx.framework/Resources
cp libsherpa-onnx-c-api.dylib sherpa_onnx.framework/sherpa_onnx
generate_info_plist "sherpa_onnx" "1.0.0" "1.0"
install_name_tool -change @rpath/libsherpa-onnx-c-api.dylib @rpath/sherpa_onnx.framework/sherpa_onnx sherpa_onnx.framework/sherpa_onnx
install_name_tool -id "@rpath/sherpa_onnx.framework/sherpa_onnx" sherpa_onnx.framework/sherpa_onnx
chmod +x sherpa_onnx.framework/sherpa_onnx
popd


# -----------------------------
# Package libsherpa-onnx-cxx-api.dylib as sherpa_onnx_cxx_api.framework
# -----------------------------
cp -v build/vision_os_sim/lib/libsherpa-onnx-cxx-api.dylib vision-sim/

pushd vision-sim
rm -rf sherpa_onnx_cxx_api.framework
mkdir -p sherpa_onnx_cxx_api.framework/Resources
cp libsherpa-onnx-cxx-api.dylib sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
generate_info_plist "sherpa_onnx_cxx_api" "1.0.0" "1.0"
install_name_tool -change @rpath/libsherpa-onnx-cxx-api.dylib @rpath/sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
install_name_tool -id "@rpath/sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api" sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
chmod +x sherpa_onnx_cxx_api.framework/sherpa_onnx_cxx_api
popd

echo "Xcode Build XCFramework"
rm -rf sherpa-onnx.xcframework

xcodebuild -create-xcframework \
  -library build/vision_os_sim/lib/libsherpa-onnx.a \
  -headers ./install/include \
  -output sherpa-onnx.xcframework

echo "Done xcframework"
echo "Remember to add the dynamic library .framework files in vision-sim"