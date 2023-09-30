# Intel Compute Runtime Depends on:
# 1. Intel(R) Graphics Compiler (igc)
# 2. Intel(R) Graphics Memory Management Library (gmmlib)
# 3. Intel(R) Graphics System Controller Firmware Update Library (igsc)

INSTALL_DIR=/home/pvelesko/space/install/intel-test

# libgmm depends on 
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/gmmlib  -S gmmlib -B gmmlib/build
cmake --build gmmlib/build --config Release -j $(nproc)
cmake --build gmmlib/build --target install

cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igsc  -S igsc -B igsc/build
cmake --build igsc/build --config Release -j $(nproc)
cmake --build igsc/build --target install

git clone -b ocl-open-140 https://github.com/intel/opencl-clang llvm-project/llvm/projects/opencl-clang
git clone -b llvm_release_140 https://github.com/KhronosGroup/SPIRV-LLVM-Translator llvm-project/llvm/projects/llvm-spirv
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/igc  -S igc -B igc/build
cmake --build igc/build --config Release -j $(nproc)
cmake --build igc/build --target install
