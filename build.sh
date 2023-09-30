# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

INSTALL_DIR=/home/pvelesko/space/install/intel-test

# get todays date in format 2023.09.30
DATE=$(date +%Y.%m.%d)

# libgmm depends on 
cmake -S gmmlib -B gmmlib/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib
cmake --build gmmlib/build --config Release -j $(nproc)
cmake --build gmmlib/build --target install

cmake -S igsc -B igsc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igsc
cmake --build igsc/build --config Release -j $(nproc)
cmake --build igsc/build --target install

git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
cmake -S igc -B igc/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igc/$DATE
cmake --build igc/build --config Release -j $(nproc)
cmake --build igc/build --target install

cmake -S neo -B neo/build -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/neo/$DATE -DGMM_DIR=/opt/install/intel/gmmlib
cmake --build neo/build --config Release -j $(nproc)
cmake --build neo/build --target install