# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

INSTALL_DIR=/home/pvelesko/space/install/intel-test

# get todays date in format 2023.09.30
DATE=$(date +%Y.%m.%d)

BUILD_TOOL="Unix Makefiles"
#BUILD_TOOL="Ninja"

# libgmm depends on 
cmake -G ${BUILD_TOOL} -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib
cmake -G ${BUILD_TOOL} --build gmmlib/build --config Release -j $(nproc) -G $
cmake -G ${BUILD_TOOL} --build gmmlib/build --target install

cmake -G ${BUILD_TOOL} -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igsc
cmake -G ${BUILD_TOOL} --build igsc/build --config Release -j $(nproc)
cmake -G ${BUILD_TOOL} --build igsc/build --target install

git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
cmake -G ${BUILD_TOOL} -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igc/$DATE -G
cmake -G ${BUILD_TOOL} --build igc/build --config Release -j $(nproc)
cmake -G ${BUILD_TOOL} --build igc/build --target install

cmake -G ${BUILD_TOOL} -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/neo/$DATE -DGMM_DIR=/opt/install/intel/gmmlib -DCMAKE_PREFIX_PATH=${INSTALL_DIR} -DSKIP_UNIT_TESTS=ON -DOCL_ICD_VENDORDIR=${INSTALL_DIR}
cmake -G ${BUILD_TOOL} --build neo/build --config Release -j $(nproc)
cmake -G ${BUILD_TOOL} --build neo/build --target install