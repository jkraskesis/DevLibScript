#!/usr/bin/env bash

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
		if [ "${COMPILER}" = "clang" ]
		then
			cat <<EOF > ~/user-config.jam
using clang : : C:/msys64/ucrt64/bin/clang++
  : <cxxflags>"-std=c++17 -D_WIN32_WINNT=0x0A00 -DBOOST_STACKTRACE_USE_BACKTRACE" 
    <linkflags>"-lbacktrace -ldl -lws2_32"
	<library-path>/ucrt64/lib
  ;
  
using gcc : 20 : C:/msys64/ucrt64/bin/clang++
  : <cxxflags>"-std=c++17 -D_WIN32_WINNT=0x0A00 -Wno-macro-redefined -DBOOST_STACKTRACE_USE_BACKTRACE" 
    <linkflags>"-lbacktrace -ldl -lws2_32 -v"
	<library-path>/ucrt64/lib
  ;
  
using gcc : : C:/msys64/ucrt64/bin/g++
    : <cxxflags>"-std=c++17 -D_WIN32_WINNT=0x0A00"
      <linkflags>"-lws2_32"
    ;
EOF
		fi		
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
						variant=debug,release link=shared runtime-link=shared address-model=64 threading=multi --layout=tagged --without-python --without-mpi
						--build-dir=${SRC_DIR}/${BOOST_DIR}/build/${OS}/${COMPILER} 
						--prefix=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged 
						--build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release --layout=tagged --without-python --without-mpi 
						--cxxflags="-std=c++17" 
						install 
						2>&1 
						| tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log 
						EOF
						)
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################## W64 ##########################################
		mkdir -p ${SRC_DIR}/tmp/${COMPILER}
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_B2=$(cat <<-EOF
						.${BOOST_DIRECTORY_SEPARATOR}b2 
						-j$NUMBER_OF_COMPILATIONS 
						toolset=gcc-20 
						variant=debug,release link=shared runtime-link=shared address-model=64 threading=multi --layout=tagged --without-python --without-mpi
						--build-dir=${SRC_DIR}/tmp/${COMPILER} 
						--prefix=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged  
						--build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release --layout=tagged --without-python --without-mpi 												
						install  
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
