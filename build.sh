#!/bin/bash
# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

# stop executing on error
set -e

if [ $# -eq 0 ]; then
    echo "Usage: build.sh [options]"
    echo "Options:"
    echo "  --download                  Download all dependencies"
    echo "  --clean                     Clean all dependencies"
    echo "  --build <install path>      Configure and build everything with CMAKE_INSTALL_PREFIX=<install path>"
    echo "  --modulefiles               Generate modulefiles"
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

# get todays date in format 2023.09.30
DATE=$(date +%Y.%m.%d)

# BUILD_TOOL=" -G Unix Makefiles"
# BUILD_TOOL="Ninja"

# METEE_INSTALL_DIR=${INSTALL_DIR}/metee/$DATE
# GMMLIB_INSTALL_DIR=${INSTALL_DIR}/gmmlib/$DATE
# IGSC_INSTALL_DIR=${INSTALL_DIR}/igsc/$DATE
# IGC_INSTALL_DIR=${INSTALL_DIR}/igc/$DATE
# NEO_INSTALL_DIR=${INSTALL_DIR}/neo/$DATE
# OCL_ICD_INSTALL_DIR=${INSTALL_DIR}/opencl/$DATE

METEE_INSTALL_DIR=${INSTALL_DIR}/metee
GMMLIB_INSTALL_DIR=${INSTALL_DIR}/gmmlib
IGSC_INSTALL_DIR=${INSTALL_DIR}/igsc
IGC_INSTALL_DIR=${INSTALL_DIR}/igc
LEVEL_ZERO_INSTALL_DIR=${INSTALL_DIR}/level-zero
NEO_INSTALL_DIR=${INSTALL_DIR}/neo
OCL_ICD_INSTALL_DIR=${INSTALL_DIR}/opencl

if [ $DOWNLOAD ]; then
    echo "Downloading all dependencies"

    git clone git@github.com:intel/metee.git
    git clone git@github.com:intel/gmmlib.git
    git clone git@github.com:intel/igsc.git
    git clone https://github.com/intel/vc-intrinsics vc-intrinsics
    # git clone -b llvmorg-14.0.5 https://github.com/llvm/llvm-project llvm-project
    # git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
    # git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
    git clone https://github.com/KhronosGroup/SPIRV-Tools.git SPIRV-Tools
    git clone https://github.com/KhronosGroup/SPIRV-Headers.git SPIRV-Headers
    git clone git@github.com:intel/intel-graphics-compiler.git igc
    git clone git@github.com:intel/compute-runtime.git neo
    git clone git@github.com:oneapi-src/level-zero.git
fi

if [ $CLEAN ]; then
    echo "Cleaning all dependencies"
    cd gmmlib; git clean -fdx; rm -rf ./build; cd ../
    cd igsc; git clean -fdx; rm -rf ./build; cd ../
    cd vc-intrinsics; git clean -fdx; rm -rf ./build; cd ../
    # cd llvm-project; git clean -fdx; rm -rf ./build; cd ../
    # cd SPIRV-Tools; git clean -fdx; rm -rf ./build; cd ../
    # cd SPIRV-Headers; git clean -fdx; rm -rf ./build; cd ../
    cd igc; git clean -fdx; rm -rf ./build; cd ../
    cd neo; git clean -fdx; rm -rf ./build; cd ../
fi

# Can't just configure in one step and then build because configuration requires built dependencies
if [ $BUILD ]; then
    echo "Building all dependencies"
    echo "Setting CC=gcc CXX=g++"

    pip install mako
    sudo apt install libllvmspirvlib-14-dev llvm-spirv-14 llvm-14 llvm-14-dev clang-14 liblld-14 liblld-14-dev

    CC=gcc CXX=g++ cmake ${BUILD_TOOL} -S metee -B metee/build -DCMAKE_INSTALL_PREFIX=${METEE_INSTALL_DIR}
    cmake ${BUILD_TOOL} --build metee/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build metee/build --target install -j $(nproc)

    CC=gcc CXX=g++ cmake ${BUILD_TOOL} -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${GMMLIB_INSTALL_DIR}
    cmake ${BUILD_TOOL} --build gmmlib/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build gmmlib/build --target install -j $(nproc)

    CC=gcc CXX=g++ cmake ${BUILD_TOOL} -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${IGSC_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${METEE_INSTALL_DIR}
    cmake ${BUILD_TOOL} --build igsc/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build igsc/build --target install -j $(nproc)

    cmake ${BUILD_TOOL} -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${IGC_INSTALL_DIR} -DIGC_OPTION__SPIRV_TOOLS_MODE=Prebuilds -DIGC_OPTION__USE_PREINSTALLED_SPIRV_HEADERS=ON -DIGC_OPTION__LLVM_PREFERRED_VERSION=14.0.0
    cmake ${BUILD_TOOL} --build igc/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build igc/build --target install  -j $(nproc)

    cmake -S level-zero -B level-zero/build -DCMAKE_INSTALL_PREFIX=${LEVEL_ZERO_INSTALL_DIR} 
    cmake ${BUILD_TOOL} --build level-zero/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build level-zero/build --target install  -j $(nproc)

    cmake ${BUILD_TOOL} -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${NEO_INSTALL_DIR} -DIGC_DIR=${IGC_INSTALL_DIR} -DGMM_DIR=${GMMLIB_INSTALL_DIR} -DCMAKE_PREFIX_PATH=${IGSC_INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${OCL_ICD_INSTALL_DIR} -DLevelZero_INCLUDE_DIR=${LEVEL_ZERO_INSTALL_DIR}/include
    cmake ${BUILD_TOOL} --build neo/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build neo/build --target install -j $(nproc)
fi

if [ $MODULEFILES ]; then
    # make sure that ./scripts/gen_modulefile.py exists
    if [ ! -f ./scripts/gen_modulefile.py ]; then
        ehco "Downloading gen_modulefile.py"
        git submodule update --init
    fi
    echo "Generating modulefiles"
    yes | ./scripts/gen_modulefile.py  ${GMMLIB_INSTALL_DIR}
    yes | ./scripts/gen_modulefile.py  ${IGSC_INSTALL_DIR}
    yes | ./scripts/gen_modulefile.py  ${IGC_INSTALL_DIR}
    yes | ./scripts/gen_modulefile.py  ${NEO_INSTALL_DIR}
    yes | ./scripts/gen_modulefile.py  ${LEVEL_ZERO_INSTALL_DIR}
    # install_dir is a variable used by gen_modulefile.py
    yes | ./scripts/gen_modulefile.py  ${OCL_ICD_INSTALL_DIR} -e OCL_ICD_VENDORS=\${install_dir}/intel.icd
fi
