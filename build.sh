# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

INSTALL_DIR=/home/pvelesko/space/install/intel-test

# get todays date in format 2023.09.30
DATE=$(date +%Y.%m.%d)

# BUILD_TOOL=" -G Unix Makefiles"
#BUILD_TOOL="Ninja"

# libgmm depends on 
git clone git@github.com:intel/gmmlib.git
cmake ${BUILD_TOOL} -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib
cmake ${BUILD_TOOL} --build gmmlib/build --config Release -j $(nproc)
cmake ${BUILD_TOOL} --build gmmlib/build --target install -j $(nproc)

git clone git@github.com:intel/igsc.git
cmake ${BUILD_TOOL} -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igsc
cmake ${BUILD_TOOL} --build igsc/build --config Release -j $(nproc)
cmake ${BUILD_TOOL} --build igsc/build --target install -j $(nproc)

git clone https://github.com/intel/vc-intrinsics vc-intrinsics
git clone -b llvmorg-14.0.5 https://github.com/llvm/llvm-project llvm-project
git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
git clone https://github.com/KhronosGroup/SPIRV-Tools.git SPIRV-Tools
git clone https://github.com/KhronosGroup/SPIRV-Headers.git SPIRV-Headers
git clone git@github.com:intel/intel-graphics-compiler.git neo
cmake ${BUILD_TOOL} -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igc/$DATE
cmake ${BUILD_TOOL} --build igc/build --config Release -j $(nproc)
cmake ${BUILD_TOOL} --build igc/build --target install  -j $(nproc)

git clone git@github.com:intel/compute-runtime.git
cmake ${BUILD_TOOL} -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/neo/$DATE -DGMM_DIR=/opt/install/intel/gmmlib -DCMAKE_PREFIX_PATH=${INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${INSTALL_DIR}/opencl
cmake ${BUILD_TOOL} --build neo/build --config Release -j $(nproc)
cmake ${BUILD_TOOL} --build neo/build --target install -j $(nproc)