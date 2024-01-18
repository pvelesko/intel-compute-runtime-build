#!/bin/bash

# if an error is enountered, exit
set -e

# check arguments
if [ $# -ne 3 ]; then
  echo "This script will download and build LLVM ${VERSION} and install it to <install_dir>."
  echo "This LLVM can be used to build the Intel Compute Runtime. Projects clang and lld enabled."
  echo "Usage: $0 <version> <install_dir> <link_type>"
  echo "version: LLVM version 14, 15, 16, 17, etc"
  echo "link_type: static or dynamic"
  exit 1
fi

# check version argument to make sure it's a number
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "Invalid version. Must be a number."
  exit 1
fi

# check link_type argument
if [ "$3" != "static" ] && [ "$3" != "dynamic" ]; then
  echo "Invalid link_type. Must be 'static' or 'dynamic'."
  exit 1
fi

VERSION=$1
INSTALL_DIR=$2
LINK_TYPE=$3

LLVM_BRANCH="release/${VERSION}.x"
TRANSLATOR_BRANCH="llvm_release_${VERSION}0"
OPENCL_CLANG_BRANCH="ocl-open-${VERSION}0"

export LLVM_DIR=`pwd`/llvm-project/llvm

# check if llvm-project exists, if not clone it
if [ ! -d llvm-project ]; then
  git clone https://github.com/llvm/llvm-project.git -b ${LLVM_BRANCH} --depth 1
  git clone https://github.com/KhronosGroup/SPIRV-LLVM-Translator.git -b ${TRANSLATOR_BRANCH} --depth 1 ${LLVM_DIR}/SPIRV-LLVM-Translator
  git clone -b ${OPENCL_CLANG_BRANCH} https://github.com/intel/opencl-clang ${LLVM_DIR}/opencl-clang
  git clone https://github.com/KhronosGroup/SPIRV-Tools.git ${LLVM_DIR}/SPIRV-Tools
else
  # Warn the user, error out
  echo "llvm-project directory already exists. Continue with configure..."
fi

# check if the build directory exists, if not create it
cd ${LLVM_DIR}
if [ ! -d build_$VERSION ]; then
  mkdir build_$VERSION
  cd build_$VERSION
else
  # Warn the user, error out
  echo "Build directory ${LLVM_DIR}/build_$VERSION already exists, please remove it and re-run the script"
  exit 1
fi

# Add build type condition
#    -DLLVM_TARGETS_TO_BUILD=host
#    -DLLVM_EXTERNAL_OPENCL_CLANG_SOURCE_DIR="${LLVM_DIR}/opencl-clang" \
#    -DLLVM_EXTERNAL_PROJECTS="opencl-clang;llvm-spirv;SPIRV-Tools" \
if [ "$LINK_TYPE" == "static" ]; then
  cmake ../  \
    -DLLVM_TARGETS_TO_BUILD=host \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_EXTERNAL_PROJECTS="opencl-clang;llvm-spirv;SPIRV-Tools" \
    -DLLVM_EXTERNAL_OPENCL_CLANG_SOURCE_DIR="${LLVM_DIR}/opencl-clang" \
    -DLLVM_EXTERNAL_SPIRV_TOOLS_SOURCE_DIR="${LLVM_DIR}/SPIRV-Tools" \
    -DLLVM_EXTERNAL_LLVM_SPIRV_SOURCE_DIR="${LLVM_DIR}/SPIRV-LLVM-Translator" \
    -DLLVM_ENABLE_PROJECTS="clang;lld"
elif [ "$LINK_TYPE" == "dynamic" ]; then
  cmake ../ \
    -DLLVM_TARGETS_TO_BUILD=host \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -DCMAKE_INSTALL_RPATH=${INSTALL_DIR}/lib \
    -DLLVM_EXTERNAL_PROJECTS="llvm-spirv;SPIRV-Tools" \
    -DLLVM_EXTERNAL_SPIRV_TOOLS_SOURCE_DIR="${LLVM_DIR}/SPIRV-Tools" \
    -DLLVM_EXTERNAL_LLVM_SPIRV_SOURCE_DIR="${LLVM_DIR}/SPIRV-LLVM-Translator" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_LINK_LLVM_DYLIB=ON \
    -DLLVM_BUILD_LLVM_DYLIB=ON \
    -DLLVM_PARALLEL_LINK_JOBS=2 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=On
else
  echo "Invalid link_type. Must be 'static' or 'dynamic'."
  exit 1
fi
