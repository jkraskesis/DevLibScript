#!/bin/bash

###################################################################
# Remove the source of the messaging library
# This also removes all compilation artifacts, NOT the installation
###################################################################
function remove_messaging_source
{
	# source directory
	if [ -d "${SRC_DIR}/${MESSAGING_DIR}" ]; then
  		rm -rf "${SRC_DIR}/${MESSAGING_DIR:?}"
	fi
}

###################################################################
# Remove all installations of the messaging library
###################################################################
function remove_messaging_installations
{
	# source directory
	if [ -d "${INSTALL_DIR}/${MESSAGING_DIR}" ]; then
  		rm -rf "${INSTALL_DIR}/${MESSAGING_DIR:?}"
	fi
}

#############################
# Clone the messaging library
#############################
function clone_messaging
{
	cd ${SRC_DIR} || exit
	git clone --branch $MESSAGING_BRANCH $MESSAGING_URL
}

#########################
# Messaging configuration
#########################
function configure_messaging
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}
	
	if [ "${COMPILER}" = "gcc" ]
	then
		COMPILATION_CXX="g++"
	fi 
	if [ "${COMPILER}" = "clang" ]
	then
		COMPILATION_CXX="clang++"
	fi

	if [ ${BUILDTOOL} = "configure" ]
	then
		MESSAGING_CONFIGURE=$(cat <<-EOF
									CXX=${COMPILATION_CXX} 
									../../../configure  
									--with-boost=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged 
									--prefix=${INSTALL_DIR}/${OS}/${MESSAGING_NAME}/${BUILDTOOL}/${COMPILER}/${MESSAGING_NAME} 
									--with-cxx=17 
									${DEBUG_ARGS} 
									2>&1 
									| tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
		echo ${MESSAGING_CONFIGURE}
	fi
	if [ ${BUILDTOOL} = "cmake" ]
	then
		MESSAGING_CONFIGURE=$(cat <<-EOF
									CMAKE_PREFIX_PATH=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged/lib/cmake 
									cmake 
									../../.. 
									-G Ninja 
									-DCMAKE_CXX_COMPILER=${COMPILATION_CXX}
									-DCMAKE_CXX_STANDARD=17 
									${DEBUG_ARGS} 
									-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/${MESSAGING_NAME}/${BUILDTOOL}/${COMPILER}/${MESSAGING_NAME} 
									2>&1 
									| tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
		echo ${MESSAGING_CONFIGURE}
	fi

	# update the Autotools files for local things
	if [ "${BUILDTOOL}" = "configure" ]
	then
		cd ${SRC_DIR}/${MESSAGING_DIR} || exit
		./autogen.sh
	fi
	
	rm -f ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 

	mkdir -p "${SRC_DIR}/${MESSAGING_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	cd "${SRC_DIR}/${MESSAGING_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"  || exit
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	
	echo "${MESSAGING_CONFIGURE}" | tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log	
	eval ${MESSAGING_CONFIGURE}
}

#######################
# Messaging compilation
#######################
function compile_messaging
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}

	rm -f ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILD_TOOL}_${COMPILER}_build.log
	rm -f ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILD_TOOL}_${COMPILER}_install.log

	cd "${SRC_DIR}/${MESSAGING_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	
	if [ ${BUILDTOOL} = "configure" ]
	then
		MAKE_COMMAND="make"
	fi 
	
	if [ ${BUILDTOOL} = "cmake" ]
	then
		MAKE_COMMAND="ninja -v"
	fi
	
	MESSAGING_MAKE="${MAKE_COMMAND} -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log"	
	echo "${MESSAGING_MAKE}" | tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log	
	eval ${MESSAGING_MAKE}
	
	MESSAGING_MAKE_INSTALL="${MAKE_COMMAND} install 2>&1 | tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_install.log"	
	echo "${MESSAGING_MAKE_INSTALL}" | tee -a ${LOG_DIR}/${MESSAGING_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	eval ${MESSAGING_MAKE_INSTALL}
}
