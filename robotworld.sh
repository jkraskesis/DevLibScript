#!/bin/bash

###################################################################
# Remove the source of the application
# This also removes all compilation artifacts, NOT the installation
###################################################################
function remove_application_source
{
	# source directory
	if [ -d "${SRC_DIR}/${APPLICATION_DIR}" ]; then
  		rm -rf "${SRC_DIR}/${APPLICATION_DIR:?}"
	fi
}

###################################################################
# Remove all installations of the application
###################################################################
function remove_messaging_installations
{
	# source directory
	if [ -d "${INSTALL_DIR}/${APPLICATION_DIR}" ]; then
  		rm -rf "${INSTALL_DIR}/${APPLICATION_DIR:?}"
	fi
}

#######################
# Clone the application
#######################
function clone_application
{
	cd ${SRC_DIR} || exit
	git clone $APPLICATION_URL
}

###########################
# Application configuration
###########################
function configure_application
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}
	
	if [ "${COMPILER}" = "gcc" ]
	then
		CXX="/usr/bin/g++"
	fi 
	if [ "${COMPILER}" = "clang" ]
	then
		CXX="/usr/bin/clang++"
	fi 

	if [ ${BUILDTOOL} = "configure" ]
	then
#	CXX=${CXX} seems to mess up the compilation?
		APPLICATION_CONFIGURE=$(cat <<-EOF
									../../../configure 
									--with-boost=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged
									--with-wx-config=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR}/bin/wx-config 
									--with-messaging=${INSTALL_DIR}/${OS}/${MESSAGING_NAME}/${BUILDTOOL}/${COMPILER}/${MESSAGING_NAME}
									--prefix=${INSTALL_DIR}/${OS}/${APPLICATION_NAME}/${BUILDTOOL}/${COMPILER}
									--with-cxx=17
									${DEBUG_ARGS} 
									2>&1 
									| tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi
	if [ ${BUILDTOOL} = "cmake" ]
	then
		APPLICATION_CONFIGURE=$(cat <<-EOF
									CMAKE_PREFIX_PATH=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged/lib/cmake:${INSTALL_DIR}/${OS}/wxwidgets/cmake/${COMPILER}/${WXWIDGETS_DIR}/lib/cmake 
									CXX=${CXX} 
									cmake 
									../../.. 
									-G "Unix Makefiles"									
									-DMESSAGEROOT=${INSTALL_DIR}/${OS}/${MESSAGING_NAME}/${BUILDTOOL}/${COMPILER}/${MESSAGING_NAME} 
									-DCMAKE_CXX_STANDARD=17 
									${DEBUG_ARGS}									
									-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/${APPLICATION_NAME}/${BUILDTOOL}/${COMPILER} 
									2>&1 
									| tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi

	# update the Autotools files for local things
	if [ "${BUILDTOOL}" = "configure" ]
	then
		cd ${SRC_DIR}/${APPLICATION_DIR} || exit
		./autogen.sh
	fi
	
	rm -f ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log 

	mkdir -p "${SRC_DIR}/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	cd "${SRC_DIR}/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit	
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	
	echo "${APPLICATION_CONFIGURE}" | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	eval ${APPLICATION_CONFIGURE}
}

#########################
# Application compilation
#########################
function compile_application
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}
	
	rm -f ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILD_TOOL_DIR}_${COMPILER}_build.log
	rm -f ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILD_TOOL_DIR}_${COMPILER}_install.log

	cd "${SRC_DIR}/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit	
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log

	APPLICATION_MAKE="make -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log"
	echo "${APPLICATION_MAKE}" | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${APPLICATION_MAKE}
	
	APPLICATION_MAKE_INSTALL="make install 2>&1 | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_install.log"
	echo "${APPLICATION_MAKE_INSTALL}" | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	eval ${APPLICATION_MAKE_INSTALL}	
}
