#!/bin/bash

###################################################################
# Remove the downloaded source of wxWidgets
# This also removes all compilation artifacts, NOT the installation
###################################################################
function remove_wxwidgets_source
{
	# source file
	if [ -f "${SRC_DIR}/${WXWIDGETS_SRC_FILE}" ]; then
  		rm "${SRC_DIR}/${WXWIDGETS_SRC_FILE:?}"
	fi
	# source and build directory
	if [ -d "${SRC_DIR}/${WXWIDGETS_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${WXWIDGETS_DIR:?}
	fi
}

#######################################
# Remove all installations of wxWidgets
#######################################
function remove_wxwidgets_installations
{
	if [ -d "${INSTALL_DIR}/${OS}/wxwidgets" ]; then
			rm -rf ${INSTALL_DIR}/${OS}/wxwidgets
	fi
}

################################
# Download and extract wxWidgets
################################
function download_and_extract_wxwidgets
{
	cd ${SRC_DIR} || exit
	# Only download the local file does not exist, or if the remote file is newer
	wget -N ${WXWIDGETS_URL}
	# Do not overwrite any existing files
	tar --skip-old-files -xjf ${WXWIDGETS_SRC_FILE}
}

#########################
# wxWidgets configuration
#########################
function configure_wxwidgets
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}
	
	if [ "${COMPILER}" = "gcc" ]
	then
		COMPILATION_CXX="/usr/bin/g++"
	fi 
	if [ "${COMPILER}" = "clang" ]
	then
		COMPILATION_CXX="/usr/bin/clang++"
	fi

	if [ ${BUILDTOOL} = "configure" ]
	then
#	CXX=${CXX} seems to mess up the compilation?
		WXWIDGETS_CONFIGURE=$(cat <<-EOF
									../../../configure 
									--enable-debug 
									--with-cxx=17 
									--prefix=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 
									2>&1 
									| tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi 
	
	if [ ${BUILDTOOL} = "cmake" ]
	then
		WXWIDGETS_CONFIGURE=$(cat <<-EOF
									CXX=${COMPILATION_CXX} 
									cmake 
									../../.. 
									-G "Unix Makefiles" 
									-DCMAKE_CXX_STANDARD=17 
									-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 
									2>&1 
									| tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi
	
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	
	mkdir -p "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	cd "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit	
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	
	echo "${WXWIDGETS_CONFIGURE}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log
	eval ${WXWIDGETS_CONFIGURE}
}

#######################
# wxWidgets compilation
#######################
function compile_wxwidgets
{
	local BUILDTOOL=$1
	local COMPILER=$2
	local OS=${OS}
	
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	
	cd "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	
	WXWIDGETS_MAKE="make -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log"
	echo "${WXWIDGETS_MAKE}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${WXWIDGETS_MAKE}
	
	WXWIDGETS_MAKE_INSTALL="make install 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log"
	echo "${WXWIDGETS_MAKE_INSTALL}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	eval ${WXWIDGETS_MAKE_INSTALL}
}
