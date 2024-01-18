#!/bin/bash
# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

# stop executing on error
set -e


# BUILD_TOOL="Ninja"
BUILD_TOOL="Unix Makefiles"

if [ $# -eq 0 ]; then
  echo "Usage: build.sh [options]"
  echo "Options:"
  echo "  --download                  Download all dependencies"
  echo "  --clean                     Clean all dependencies"
  echo "  --build <install path>      Configure and build everything with CMAKE_INSTALL_PREFIX=<install path>"
  echo "  --modulefiles               Generate modulefiles"
  echo "  --igc-tag <tag>             Specify the IGC tag"
  echo "  --neo-tag <tag>             Specify the NEO tag"
  echo "  -h, --help                  Show this help message"
  exit 1
fi

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --download)
      DOWNLOAD=true
      ;;
    --clean)
      CLEAN=true
      ;;
    --build)
      BUILD=true
      shift
      if [ -z "$1" ] || [[ "$1" == --* ]]; then
        echo "Error: Invalid path provided for --build : $1"
        exit 1
      else
        INSTALL_DIR="$1"
      fi
      ;;
    --modulefiles)
      MODULEFILES=true
      ;;
    --igc-tag)
      shift
      if [ -z "$1" ] || [[ "$1" == --* ]]; then
        echo "Error: Invalid tag provided for --igc-tag : $1"
        exit 1
      else
        IGC_TAG="$1"
      fi
      ;;
    --neo-tag)
      shift
      if [ -z "$1" ] || [[ "$1" == --* ]]; then
        echo "Error: Invalid tag provided for --neo-tag : $1"
        exit 1
      else
        NEO_TAG="$1"
      fi
      ;;
    -h|--help)
      HELP=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

checkout_tags() {
  # if NEO_TAG is not set, use the latest tag
  if [ -z "$NEO_TAG" ]; then
    pushd neo
    git fetch --tags
    NEO_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
    # checkout the tag
    git checkout -f $NEO_TAG
    popd
  fi

  # if IGC_TAG is not set, use the latest tag
  if [ -z "$IGC_TAG" ]; then
    pushd igc
    git fetch --tags
    IGC_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
    # checkout the tag
    git checkout -f $IGC_TAG
    popd
  fi

  # Other dependencies don't seem to be frequently updated so just use the latest tag
  for repo in metee gmmlib igsc vc-intrinsics level-zero; do
    pushd $repo
    git fetch --tags
    TAG=$(git describe --tags `git rev-list --tags --max-count=1`)
    git checkout -f $TAG
    popd
  done

  # setup install dirs
  METEE_INSTALL_DIR=${INSTALL_DIR}/metee/${METEE_TAG}
  GMMLIB_INSTALL_DIR=${INSTALL_DIR}/gmmlib/${GMMLIB_TAG}
  IGSC_INSTALL_DIR=${INSTALL_DIR}/igsc/${IGSC_TAG}
  IGC_INSTALL_DIR=${INSTALL_DIR}/igc/${IGC_TAG}
  NEO_INSTALL_DIR=${INSTALL_DIR}/neo/${NEO_TAG}
  LEVEL_ZERO_INSTALL_DIR=${INSTALL_DIR}/level-zero/${NEO_TAG}
  OCL_ICD_INSTALL_DIR=${INSTALL_DIR}/opencl

  #dump install dir vars to cache.txt
  echo "METEE_INSTALL_DIR=${METEE_INSTALL_DIR}" | tee cache.txt
  echo "GMMLIB_INSTALL_DIR=${GMMLIB_INSTALL_DIR}" | tee -a cache.txt
  echo "IGSC_INSTALL_DIR=${IGSC_INSTALL_DIR}" | tee -a cache.txt
  echo "IGC_INSTALL_DIR=${IGC_INSTALL_DIR}" | tee -a cache.txt
  echo "NEO_INSTALL_DIR=${NEO_INSTALL_DIR}" | tee -a cache.txt
  echo "LEVEL_ZERO_INSTALL_DIR=${LEVEL_ZERO_INSTALL_DIR}" | tee -a cache.txt
  echo "OCL_ICD_INSTALL_DIR=${OCL_ICD_INSTALL_DIR}" | tee -a cache.txt
}

LLVM_VERSION=$(clang-14 --version | grep -o 'version [0-9]*\.[0-9]*\.[0-9]*' | awk '{print $2}')

IGC_OPTS="-DCCLANG_BUILD_PREBUILDS=ON -DCCLANG_BUILD_PREBUILDS_DIR=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__ARCHITECTURE_TARGET=Linux64 -DIGC_OPTION__LLVM_MODE=Prebuilds -DLLVM_ROOT=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__LLVM_PREFERRED_VERSION=${LLVM_VERSION}"
# IGC_OPTS="-DIGC_OPTION__ARCHITECTURE_TARGET=Linux64 -DIGC_OPTION__LLVM_MODE=Prebuilds -DLLVM_ROOT=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__LLVM_PREFERRED_VERSION=${LLVM_VERSION}"

if [ $DOWNLOAD ]; then
    echo "Downloading all dependencies"

    git clone https://github.com/intel/metee.git
    git clone https://github.com/intel/gmmlib.git
    git clone https://github.com/intel/igsc.git
    git clone https://github.com/intel/vc-intrinsics vc-intrinsics
    git clone https://github.com/intel/intel-graphics-compiler.git igc
    git clone https://github.com/intel/compute-runtime.git neo
    git clone https://github.com/oneapi-src/level-zero.git
fi

if [ $CLEAN ]; then
    echo "clean - TODO"
fi

# Can't just configure in one step and then build because configuration requires built dependencies
if [ $BUILD ]; then
    # checkout_tags
    source cache.txt

    echo "Building all dependencies"
    echo "Setting CC=gcc CXX=g++"

    pip install mako
    # sudo apt install libllvmspirvlib-14-dev llvm-spirv-14 llvm-14 llvm-14-dev clang-14 liblld-14 liblld-14-dev

    # check if installed, if not install
    if [ ! -d ${METEE_INSTALL_DIR} ]; then
      rm -f metee/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S metee -B metee/build -DCMAKE_INSTALL_PREFIX=${METEE_INSTALL_DIR}
      cmake  --build metee/build --config Release -j $(nproc)
      cmake  --build metee/build --target install -j $(nproc)
    fi 

    if [ ! -d ${GMMLIB_INSTALL_DIR} ]; then
      rm -f gmmlib/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${GMMLIB_INSTALL_DIR}
      cmake --build gmmlib/build --config Release -j $(nproc)
      cmake --build gmmlib/build --target install -j $(nproc)
    fi

    if [ ! -d ${IGSC_INSTALL_DIR} ]; then
      rm -f igsc/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${IGSC_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${METEE_INSTALL_DIR}
      cmake --build igsc/build --config Release -j $(nproc)
      cmake --build igsc/build --target install -j $(nproc)
    fi

    if [ ! -d ${IGC_INSTALL_DIR} ]; then
      rm -f igc/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${IGC_INSTALL_DIR} ${IGC_OPTS}
      cmake --build igc/build --config Release -j $(nproc)
      cmake --build igc/build --target install  -j $(nproc)
    fi

    if [ ! -d ${LEVEL_ZERO_INSTALL_DIR} ]; then
      rm -f level-zero/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S level-zero -B level-zero/build -DCMAKE_INSTALL_PREFIX=${LEVEL_ZERO_INSTALL_DIR} -DIGC_DIR=${IGC_INSTALL_DIR}
      cmake --build level-zero/build --config Release -j $(nproc)
      cmake --build level-zero/build --target install  -j $(nproc)
    fi

    if [ ! -d ${NEO_INSTALL_DIR} ]; then
      rm  -f neo/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${NEO_INSTALL_DIR} -DIGC_DIR=${IGC_INSTALL_DIR} -DGMM_DIR=${GMMLIB_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${IGSC_INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${NEO_INSTALL_DIR}/etc/OpenCL/vendors -DLevelZero_INCLUDE_DIR=${LEVEL_ZERO_INSTALL_DIR}/include
      cmake --build neo/build --config Release -j $(nproc)
      cmake --build neo/build --target install -j $(nproc)
    fi
fi


if [ $MODULEFILES ]; then
  # make sure that ./scripts/gen_modulefile.py exists
  if [ ! -f ./scripts/gen_modulefile.py ]; then
      echo "Downloading gen_modulefile.py"
      git submodule update --init
  fi

  # prompt the user to enter the modulefiles directory
  echo "Enter the modulefiles directory"
  read MODULEFILES_DIR

  source cache.txt
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${GMMLIB_INSTALL_DIR}
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${IGSC_INSTALL_DIR}
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${IGC_INSTALL_DIR}
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${NEO_INSTALL_DIR} -e OCL_ICD_VENDORS=\${install_dir}/etc/OpenCL/vendors -e OCL_ICD_FILENAMES=\${install_dir}/etc/OpenCL/vendors/intel.icd
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${LEVEL_ZERO_INSTALL_DIR}
fi
  
