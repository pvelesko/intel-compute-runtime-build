#!/bin/bash
# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

# stop executing on error
set -e


# check if ninja exists and if so set BUILD_TOOL 
if command -v ninja &> /dev/null
then
  BUILD_TOOL="Ninja"
else
  BUILD_TOOL="Unix Makefiles"
fi

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

  # strip trailing /
  METEE_INSTALL_DIR=$(echo $METEE_INSTALL_DIR | sed 's:/*$::')
  GMMLIB_INSTALL_DIR=$(echo $GMMLIB_INSTALL_DIR | sed 's:/*$::')
  IGSC_INSTALL_DIR=$(echo $IGSC_INSTALL_DIR | sed 's:/*$::')
  IGC_INSTALL_DIR=$(echo $IGC_INSTALL_DIR | sed 's:/*$::')
  NEO_INSTALL_DIR=$(echo $NEO_INSTALL_DIR | sed 's:/*$::')
  LEVEL_ZERO_INSTALL_DIR=$(echo $LEVEL_ZERO_INSTALL_DIR | sed 's:/*$::')
  OCL_ICD_INSTALL_DIR=$(echo $OCL_ICD_INSTALL_DIR | sed 's:/*$::')

  #dump install dir vars to cache.txt
  echo "METEE_INSTALL_DIR=${METEE_INSTALL_DIR}" | tee -a cache.txt
  echo "GMMLIB_INSTALL_DIR=${GMMLIB_INSTALL_DIR}" | tee -a cache.txt
  echo "IGSC_INSTALL_DIR=${IGSC_INSTALL_DIR}" | tee -a cache.txt
  echo "IGC_INSTALL_DIR=${IGC_INSTALL_DIR}" | tee -a cache.txt
  echo "NEO_INSTALL_DIR=${NEO_INSTALL_DIR}" | tee -a cache.txt
  echo "LEVEL_ZERO_INSTALL_DIR=${LEVEL_ZERO_INSTALL_DIR}" | tee -a cache.txt
  echo "OCL_ICD_INSTALL_DIR=${OCL_ICD_INSTALL_DIR}" | tee -a cache.txt
}

if [ $DOWNLOAD ]; then
    rm -f cache.txt
    # ask the user if clang-14 with opencl-clang is installed or if it should be built
    echo "Do you have clang-14 with opencl-clang installed? (y/n)"
    read CLANG_INSTALLED
    if [ $CLANG_INSTALLED == "y" ]; then
      LLVM_VERSION=$(clang-14 --version | grep -o 'version [0-9]*\.[0-9]*\.[0-9]*' | awk '{print $2}')
      echo "LLVM_VERSION=${LLVM_VERSION}" | tee -a cache.txt
      IGC_OPTS="\"-DIGC_OPTION__ARCHITECTURE_TARGET=Linux64 -DIGC_OPTION__LLVM_MODE=Prebuilds -DLLVM_ROOT=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__LLVM_PREFERRED_VERSION=${LLVM_VERSION}\""
      #IGC_OPTS="-DCCLANG_BUILD_PREBUILDS=ON -DCCLANG_BUILD_PREBUILDS_DIR=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__ARCHITECTURE_TARGET=Linux64 -DIGC_OPTION__LLVM_MODE=Prebuilds -DLLVM_ROOT=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__LLVM_PREFERRED_VERSION=${LLVM_VERSION}"
      #IGC_OPTS="-DIGC_OPTION__ARCHITECTURE_TARGET=Linux64 -DIGC_OPTION__LLVM_MODE=Prebuilds -DLLVM_ROOT=$(dirname $(dirname $(which clang++))) -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__LLVM_PREFERRED_VERSION=${LLVM_VERSION}
    else
      IGC_OPTS="-DLLVM_TARGETS_TO_BUILD=X86 -DIGC_OPTION__LLVM_MODE=Source -DIGC_OPTION__SPIRV_TOOLS_MODE=Source"
    fi
    echo "IGC_OPTS=${IGC_OPTS}" | tee -a cache.txt


    echo "Downloading all dependencies"
    set +e

    git clone https://github.com/intel/metee.git
    git clone https://github.com/intel/gmmlib.git
    git clone https://github.com/intel/igsc.git

    git clone https://github.com/intel/intel-graphics-compiler.git igc
    git clone https://github.com/intel/vc-intrinsics vc-intrinsics

    if [ $CLANG_INSTALLED == "n" ]; then
      git clone -b llvmorg-14.0.5 https://github.com/llvm/llvm-project llvm-project
      git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
      git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator  --depth 1 llvm-project/llvm/projects/llvm-spirv
      git clone https://github.com/KhronosGroup/SPIRV-Tools.git SPIRV-Tools
    fi

    git clone https://github.com/KhronosGroup/SPIRV-Headers.git SPIRV-Headers
    git clone https://github.com/intel/compute-runtime.git neo
    git clone https://github.com/oneapi-src/level-zero.git
    set -e
fi

if [ $CLEAN ]; then
  # delete all git cloned repos
  echo "Cleaning all dependencies"
  rm -rf metee gmmlib igsc igc vc-intrinsics llvm-project SPIRV-Headers SPIRV-Tools neo level-zero cache.txt
fi

# Can't just configure in one step and then build because configuration requires built dependencies
if [ $BUILD ]; then
    checkout_tags
    source cache.txt

    #CMAKE_PREFIX="-DCMAKE_PREFIX_PATH=${METEE_INSTALL_DIR}:${IGC_INSTALL_DIR}"

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
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${IGSC_INSTALL_DIR} $CMAKE_PREFIX
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
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S level-zero -B level-zero/build -DCMAKE_INSTALL_PREFIX=${LEVEL_ZERO_INSTALL_DIR} $CMAKE_PREFIX
      cmake --build level-zero/build --config Release -j $(nproc)
      cmake --build level-zero/build --target install  -j $(nproc)
    fi

    # TODO: issue CMAKE_INSTALL_PREFIX doesn't work for detecting GMM_DIR
    
    if [ ! -d ${NEO_INSTALL_DIR} ]; then
      rm  -f neo/build/CMakeCache.txt
      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${NEO_INSTALL_DIR} -DIGC_DIR=${IGC_INSTALL_DIR} -DGMM_DIR=${GMMLIB_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${IGSC_INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${NEO_INSTALL_DIR}/etc/OpenCL/vendors -DLevelZero_INCLUDE_DIR=${LEVEL_ZERO_INSTALL_DIR}/include -DNEO_ENABLE_i915_PRELIM_DETECTION=ON
#      CC=gcc CXX=g++ cmake -G "${BUILD_TOOL}" -S neo -B neo/build -DGMM_DIR=${GMMLIB_INSTALL_DIR} -DCMAKE_INSTALL_PREFIX=${NEO_INSTALL_DIR} $CMAKE_PREFIX -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${NEO_INSTALL_DIR}/etc/OpenCL/vendors -DNEO_ENABLE_i915_PRELIM_DETECTION=ON
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
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${NEO_INSTALL_DIR} -e OCL_ICD_VENDORS=\${install_dir}/etc/OpenCL/vendors -e OCL_ICD_FILENAMES=\${install_dir}/etc/OpenCL/vendors/intel.icd --prereq intel-compute-runtime/igc
  yes | ./scripts/gen_modulefile.py --modulefiles $MODULEFILES_DIR ${LEVEL_ZERO_INSTALL_DIR}
fi
  
