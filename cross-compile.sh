#!/bin/bash

set -e

TARGET_ARCH=$1
if [ -z $TARGET_ARCH ]; then
    echo "You must provide a target architecture as the first argument!"
    echo "Common options: aarch64, armv7, x86_64"
    echo "Usage: ./cross-compile.sh <target-arch> [distro]"
    exit 1
fi

DISTRO=$2
DISTRO=${DISTRO:=debian_bookworm}
DISTRO=${DISTRO//-/_} # ensure that dashes are replaced with underscores

# Pass env variables to customize build profile, scratch path, Swift version, or entire SDK ID
BUILD_PROFILE=${BUILD_PROFILE:=debug}
SCRATCH_PATH=${SCRATCH_PATH:=.build-${TARGET_ARCH}}
SWIFT_VERSION=${SWIFT_VERSION:=$(cat .swift-version)-RELEASE}
SWIFT_SDK_ID=${SWIFT_SDK_ID:=${SWIFT_VERSION}_${DISTRO}_${TARGET_ARCH}}

if swift sdk list | grep -q $SWIFT_SDK_ID; then
    echo "Swift SDK $SWIFT_SDK_ID found."
else
    echo "Swift SDK $SWIFT_SDK_ID not found! You must have it installed to cross-compile."
    echo "Use the https://github.com/swiftlang/swift-sdk-generator to generate & install these Swift SDKs."
    exit 1
fi

echo "Cross-compiling for $TARGET_ARCH in $BUILD_PROFILE mode at $SCRATCH_PATH..."
swift build -c $BUILD_PROFILE --scratch-path $SCRATCH_PATH --swift-sdk $SWIFT_SDK_ID

echo "NOTE: Any compiled binaries can be found at $SCRATCH_PATH/$BUILD_PROFILE/"
