#/bin/bash
# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

# Argument parsing: --install-dir, --download, --clean, --build, --help
if [ $# -eq 0 ]; then
    echo "Usage: build.sh [options]"
    echo "Options:"
    echo "  -i, --install-dir <path>   Path to install directory"
    echo "  -d, --download             Download all dependencies"
    echo "  -c, --clean                Clean all dependencies"
    echo "  -b, --build                Build all dependencies"
    echo "  -h, --help                 Show this help message"
    exit 1
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
        -i | --install-dir )    shift
                                INSTALL_DIR=$1
                                ;;
        -d | --download )       DOWNLOAD=1
                                ;;
        -c | --clean )          CLEAN=1
                                ;;
        -b | --build )          BUILD=1
                                ;;
        -h | --help )           HELP=1
                                ;;
        * )                     HELP=1
                                ;;
    esac
    shift
done

# Require to provide --install-dir if --build
#if [ $BUILD ]; then
#    if [ -z $INSTALL_DIR ]; then
#        echo "Please provide --install-dir"
#        exit 1
#    fi
#fi

# get todays date in format 2023.09.30
DATE=$(date +%Y.%m.%d)

# BUILD_TOOL=" -G Unix Makefiles"
# BUILD_TOOL="Ninja"

if [ $HELP ]; then
    echo "Usage: build.sh [options]"
    echo "Options:"
    echo "  -i, --install-dir <path>   Path to install directory"
    echo "  -d, --download             Download all dependencies"
    echo "  -c, --clean                Clean all dependencies"
    echo "  -b, --build                Build all dependencies"
    echo "  -h, --help                 Show this help message"
    exit 1
fi

if [ $DOWNLOAD ]; then
    echo "Downloading all dependencies"

    git clone git@github.com:intel/gmmlib.git
    git clone git@github.com:intel/igsc.git
    git clone https://github.com/intel/vc-intrinsics vc-intrinsics
    git clone -b llvmorg-14.0.5 https://github.com/llvm/llvm-project llvm-project
    git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
    git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
    git clone https://github.com/KhronosGroup/SPIRV-Tools.git SPIRV-Tools
    git clone https://github.com/KhronosGroup/SPIRV-Headers.git SPIRV-Headers
    git clone git@github.com:intel/intel-graphics-compiler.git igc
    git clone git@github.com:intel/compute-runtime.git neo
fi

if [ $CLEAN ]; then
    echo "Cleaning all dependencies"
    cd gmmlib; git clean -fdx; cd ../
    cd igsc; git clean -fdx; cd ../
    cd vc-intrinsics; git clean -fdx; cd ../
    cd llvm-project; git clean -fdx; cd ../
    cd SPIRV-Tools; git clean -fdx; cd ../
    cd SPIRV-Headers; git clean -fdx; cd ../
    cd igc; git clean -fdx; cd ../
    cd neo; git clean -fdx; cd ../
fi

if [ $BUILD ]; then
    echo "Building all dependencies"
    echo "Setting CC=gcc CXX=g++"

    # if no INSTALL_DIR provided, do not add -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib
    CC=gcc CXX=g++ cmake ${BUILD_TOOL} -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib
    cmake ${BUILD_TOOL} --build gmmlib/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build gmmlib/build --target install -j $(nproc)


    CC=gcc CXX=g++ cmake ${BUILD_TOOL} -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igsc
    cmake ${BUILD_TOOL} --build igsc/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build igsc/build --target install -j $(nproc)


    cmake ${BUILD_TOOL} -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igc/$DATE
    cmake ${BUILD_TOOL} --build igc/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build igc/build --target install  -j $(nproc)


    cmake ${BUILD_TOOL} -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/neo/$DATE -DGMM_DIR=${INSTALL_DIR}/gmmlib -DCMAKE_PREFIX_PATH=${INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${INSTALL_DIR}/opencl
    cmake ${BUILD_TOOL} --build neo/build --config Release -j $(nproc)
    cmake ${BUILD_TOOL} --build neo/build --target install -j $(nproc)
fi
