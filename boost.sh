#!/bin/bash

###################################################################
# Remove the source of Boost
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_boost_source
{
	# source file
	if [ -f "${SRC_DIR}/${BOOST_SRC_FILE}" ]; then
  		rm ${SRC_DIR}/${BOOST_SRC_FILE:?}
	fi
	# source and build directory
	if [ -d "${SRC_DIR}/${BOOST_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${BOOST_DIR:?}
	fi
}

###################################################################
# Remove all installations of Boost
################################################################### 
function remove_boost_installations
{
	# installation directory
	if [ -d "${INSTALL_DIR}/${OS}/boost" ]; then
  		rm -rf ${INSTALL_DIR}/${OS}/boost
	fi
}

############################
# Download and extract Boost
############################
function download_and_extract_boost
{
	cd ${SRC_DIR} || exit
	# Only download the local file does not exist, or if the remote file is newer
	wget -N ${BOOST_URL}
	# Do not overwrite any existing files
	tar --skip-old-files -xjf ${BOOST_SRC_FILE}
}

#########################################
# Boost configuration (compilation of b2)
#########################################
function configure_boost
{
	local COMPILER=${1}
	
	# Separate Linux and Darwin in anticipation for differences...
	case ${OS} in
	darwin*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################	
		;&
	linux*)
		########################################## Linux ##########################################
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.sh
		BOOST_BOOTSTRAP=".${BOOST_DIRECTORY_SEPARATOR}$BOOST_BOOTSTRAP_COMMAND ${COMPILER} 2>&1 | tee -a ${LOG_DIR}/boost_b2_build.log"
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################## W64 ##########################################
		# See introduction of the configuration.
		# Replace the '/' in the Unix path with '\' in the Windows path
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.sh
		BOOST_BOOTSTRAP=".${BOOST_DIRECTORY_SEPARATOR}$BOOST_BOOTSTRAP_COMMAND ${COMPILER} 2>&1 | tee -a ${LOG_DIR}/boost_b2_build.log"
		########################################## W64 ##########################################
		;;		
	esac

	rm -f ${LOG_DIR}/boost_b2_build.log
	
	cd ${SRC_DIR}/${BOOST_DIR}  || exit	
	echo "Current directory: "$(pwd) | tee ${LOG_DIR}/boost_b2_build.log
	
	echo "${BOOST_BOOTSTRAP}" | tee -a ${LOG_DIR}/boost_b2_build.log
	eval ${BOOST_BOOTSTRAP}
}

###################
# Boost compilation
###################
function compile_boost
{
	local COMPILER=${1}
	
	case ${OS} in
	darwin*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################
		;;
	linux*)
		########################################## Linux ##########################################
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_B2=$(cat <<-EOF
						.${BOOST_DIRECTORY_SEPARATOR}b2 
						-j$NUMBER_OF_COMPILATIONS 
						toolset=${COMPILER} 
						--build-dir=${SRC_DIR}/${BOOST_DIR}/build/${OS}/${COMPILER} 
						--stagedir=${SRC_DIR}/${BOOST_DIR}/stage/${OS}/${COMPILER} 
						--prefix=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged 
						--build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release --layout=tagged --without-python --without-mpi 
						--cxxflags="-std=c++17" 
						install stage 
						2>&1 
						| tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log 
						EOF
						)
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################## W64 ##########################################
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_B2=$(cat <<-EOF
						.${BOOST_DIRECTORY_SEPARATOR}b2 
						-j$NUMBER_OF_COMPILATIONS 
						toolset=${COMPILER} 
						--build-dir=${SRC_DIR}/${BOOST_DIR}/build/${OS}/${COMPILER} 
						--stagedir=${SRC_DIR}/${BOOST_DIR}/stage/${OS}/${COMPILER} 
						--prefix=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged 
						--build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release --layout=tagged --without-python --without-mpi 
						--cxxflags="-std=c++17" 
						install stage 
						2>&1 
						| tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log 
						EOF
						)
		########################################## W64 ##########################################
		;;
	esac
	
	rm -f ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	
	cd "${SRC_DIR}/${BOOST_DIR}"  || exit	
	echo "Current directory: "$(pwd) | tee ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	
	echo "${BOOST_B2}" 2>&1 | tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	eval ${BOOST_B2}
}
