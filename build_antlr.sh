#!/bin/bash

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################

ANTLR_JAR_URL=https://www.antlr.org/download/antlr-4.13.2-complete.jar
ANTLR_SRC_URL=https://www.antlr.org/download/antlr4-cpp-runtime-4.13.2-source.zip

ANTLR_SRC_FILE=${ANTLR_SRC_URL##*/} # translates the download url to antlr4-cpp-runtime-4.13.2-source.zip
ANTLR_DIR=${ANTLR_SRC_FILE%.zip}  # translates the antlr4-cpp-runtime-4.13.2-source.zip to antlr4-cpp-runtime-4.13.2-source

HOME=~

SRC_DIR=${HOME}/devlib/src
INSTALL_DIR=${HOME}/devlib/
LOG_DIR=${HOME}/devlib/logs

mkdir -p ${INSTALL_DIR}/linux/antlr/javalib
cd ${INSTALL_DIR}/linux/antlr/javalib
wget -N ${ANTLR_JAR_URL}

mkdir -pcd ${SRC_DIR}
cd ${SRC_DIR}
wget -N ${ANTLR_SRC_URL}
unzip ${ANTLR_SRC_FILE} -d ${SRC_DIR}/${ANTLR_DIR}
cd ${SRC_DIR}/${ANTLR_DIR}

mkdir build && cd build
CMAKE_PREFIX_PATH=${ANTLR_SRC_FILE}/${SRC_DIR}/cmake  cmake .. -DANTLR_JAR_LOCATION=${INSTALL_DIR}/linux/antlr/javalib/antlr-4.13.2-complete.jar -DANTLR4_INSTALL=1 -DWITH_DEMO=True
DESTDIR=${INSTALL_DIR}/linux/antlr make -j 30 install