#!/bin/bash

# script adapted as per https://github.com/root-project/cling/issues/531
# reason for the adaption: https://github.com/root-project/cling/issues/536#issuecomment-2518170063

# use ccache
export PATH=/usr/lib/ccache:$PATH

HOME=~

SRC_DIR=${HOME}/devlib/src
INSTALL_DIR=${HOME}/devlib/linux/cling
LOG_DIR=${HOME}/devlib/logs

mkdir -p ${SRC_DIR}/cling 
cd ${SRC_DIR}/cling

# follow the README.md
git clone https://github.com/root-project/llvm-project.git
cd llvm-project
git checkout cling-latest
cd ..
git clone https://github.com/root-project/cling.git
mkdir cling-build && cd cling-build
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} -DLLVM_EXTERNAL_PROJECTS=cling -DLLVM_EXTERNAL_CLING_SOURCE_DIR=../cling/ -DLLVM_ENABLE_PROJECTS="clang" -DLLVM_TARGETS_TO_BUILD="host;NVPTX" -DCMAKE_BUILD_TYPE=Release ../llvm-project/llvm

# build clang
cmake --build . -j 25 --target clang

# then cling
cmake --build . -j 25 --target cling

# install
cmake --build . -j 25 --target install
