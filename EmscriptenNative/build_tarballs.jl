###
# EmscriptenBuilder
###

using BinaryBuilder

# Collection of sources required to build Emscripten
emscripten_version="1.38.24"
lld_ver=""
sources = [
    "https://github.com/llvm-mirror/lld/archive/0a0e0cb4cce9d95873248788de7ba620b6918236.tar.gz" =>
    "64d9049c5feb83838b1e01eed8630ee12c0229420d44e23b2141ee84c990b680",
    "https://github.com/llvm-mirror/clang/archive/08d0c133ccb1b530ed743a021dc5995fbcdaf012.tar.gz" =>
    "f2036c5510d35b1e1a7574eb5bc533500e44d33127c74865763789569e1ab47a",
    "https://github.com/llvm-mirror/llvm/archive/74ebd8a99755a5e0e1c14001de05fc089f0ee28f.tar.gz" =>
    "6ec65900a9a07e605328d19d3768b8032ccc077c1abd5a1ac26b6290fbe301b8",
    "https://github.com/kripken/emscripten/archive/$(emscripten_version).tar.gz" =>
    "aa9823eda30db16629c54c85b5eaec352fcf251d2ad860e7e5917c512bdb75f6",
    "https://github.com/WebAssembly/binaryen/archive/version_58.tar.gz" =>
    "faab2ee97a4adc2607ae058bc880a5c9b99fb613c9b8397c68adefe82436812b",
]

emscripten_version = VersionNumber(emscripten_version)

script = raw"""
# We want to exit the program if errors occur.
set -o errexit

apk add nodejs
cd $WORKSPACE/srcdir/
mv llvm* llvm
mv lld* llvm/tools/lld
mv clang* llvm/tools/clang

mkdir ${prefix}/lib
mv emscripten-* ${prefix}/lib/emscripten
EMSCRIPTEN=/opt/${target}/lib/emscripten
mv binaryen-ver* binaryen
mkdir ${prefix}/lib/emscripten-cache
mkdir ${prefix}/lib/llvm

# cd $WORKSPACE/srcdir/
# git clone --depth 1 https://github.com/llvm-mirror/llvm.git
# cd $WORKSPACE/srcdir/llvm/tools
# git clone --depth 1 https://github.com/llvm-mirror/lld.git
# git clone --depth 1 https://github.com/llvm-mirror/clang.git

cd $WORKSPACE/srcdir/llvm
# Let's do the actual build within the `build` subdirectory
mkdir build && cd build

cmake -G "Unix Makefiles" \
    -DLLVM_TARGETS_TO_BUILD:STRING="WebAssembly" \
    -DLLVM_PARALLEL_COMPILE_JOBS=$(($(nproc)+1)) \
    -DLLVM_PARALLEL_LINK_JOBS=$(($(nproc)+1)) \
    -DLLVM_BINDINGS_LIST="" \
    -DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-unknown-unknown \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_ASSERTIONS=Off \
    -DCMAKE_INSTALL_PREFIX=${prefix}/lib/llvm \
    -DLIBCXX_HAS_MUSL_LIBC=On \
    -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
    -DLLVM_TARGET_TRIPLE_ENV=LLVM_TARGET \
    -DCOMPILER_RT_BUILD_SANITIZERS=Off \
    -DCOMPILER_RT_BUILD_PROFILE=Off \
    -DCOMPILER_RT_BUILD_LIBFUZZER=Off \
    -DCOMPILER_RT_BUILD_XRAY=Off \
    -DCMAKE_SKIP_RPATH=YES \
    -DLLVM_BUILD_RUNTIME=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DCLANG_INCLUDE_TESTS=OFF \
    ..
#make -j$(($(nproc)+1))
make
make install

cd $WORKSPACE/srcdir/binaryen
cmake -DCMAKE_INSTALL_PREFIX=${prefix} -DCMAKE_BUILD_TYPE=Release
make -j$(($(nproc)+1))
make install
BINARYEN_ROOT=/opt/${target}/
BINARYEN=/opt/${target}/

# Run a test to pre-populate Emscripten's cache
export EM_CACHE=${prefix}/lib/emscripten-cache
export PATH=${prefix}/lib/emscripten:${prefix}/lib/llvm/bin:${prefix}/bin:$PATH
export BINARYEN=/opt/x86_64-linux-gnu/
cd ${prefix}/lib/emscripten
emcc -v
# python tests/runner.py test_loop

"""

platforms = [
    BinaryProvider.Linux(:x86_64, :glibc)
]

# The products that we will ensure are always built
products(prefix) = [
    # libraries
    LibraryProduct(prefix, "libLLVM",  :libLLVM)
    LibraryProduct(prefix, "libLTO",   :libLTO)
    LibraryProduct(prefix, "libclang", :libclang)
    # tools
    ExecutableProduct(joinpath(prefix, "tools", "llvm-config"), :llvm_config)
]

# Dependencies that must be installed before this package can be built
dependencies = [
]

config = ""
name = "EmscriptenNative"

build_tarballs(["--verbose", "--debug"], name, emscripten_version, sources, script, platforms, products, dependencies; skip_audit=true)
