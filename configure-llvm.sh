#!/bin/bash

# if an error is enountered, exit
set -e

# check arguments
if [ $# -ne 1 ]; then
  echo "This script will download and build LLVM ${VERSION} and install it to <install_dir>."
  echo "This LLVM can be used to build the Intel Compute Runtime. Projects clang and lld enabled."
  echo "Usage: <install_dir>"
  exit 1
fi

VERSION=14
INSTALL_DIR=$1

LLVM_BRANCH="release/${VERSION}.x"
TRANSLATOR_BRANCH="llvm_release_${VERSION}0"
OPENCL_CLANG_BRANCH="ocl-open-${VERSION}0"

export LLVM_DIR=`pwd`/llvm-project/llvm
export EXTERNAL_DIR=${LLVM_DIR}/external

#git clone https://github.com/intel/opencl-clang -b ${OPENCL_CLANG_BRANCH} ${EXTERNAL_DIR}/opencl-clang
# check if llvm-project exists, if not clone it
if [ ! -d llvm-project ]; then
  git clone https://github.com/llvm/llvm-project.git -b ${LLVM_BRANCH} --depth 1
  git clone https://github.com/KhronosGroup/SPIRV-LLVM-Translator.git -b ${TRANSLATOR_BRANCH} --depth 1 ${EXTERNAL_DIR}/SPIRV-LLVM-Translator
  git clone https://github.com/KhronosGroup/SPIRV-Tools.git ${EXTERNAL_DIR}/SPIRV-Tools
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

cmake ../  \
  -DCMAKE_CXX_STANDARD=17 \
  -DLLVM_TARGETS_TO_BUILD=host \
  -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;lld" \
  -DLLVM_EXTERNAL_PROJECTS="llvm-spirv;opencl-clang;SPIRV-Tools" \
  -DLLVM_EXTERNAL_OPENCL_CLANG_SOURCE_DIR="${EXTERNAL_DIR}/opencl-clang" \
  -DLLVM_EXTERNAL_SPIRV_TOOLS_SOURCE_DIR="${EXTERNAL_DIR}/SPIRV-Tools" \
  -DLLVM_EXTERNAL_LLVM_SPIRV_SOURCE_DIR="${EXTERNAL_DIR}/SPIRV-LLVM-Translator"
