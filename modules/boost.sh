#!/usr/bin/env bash

###################################################################
# Remove the source of Boost
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_boost_source
{
	if [ "${CROSS_COMPILING}" = true ]; then
		echo "Reusing isolated Boost sources: ${SRC_DIR}/${BOOST_DIR}"
		return
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command rm -f "${SRC_DIR}/${BOOST_SRC_FILE}"
		preview_command rm -rf "${SRC_DIR}/${BOOST_DIR}"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		return
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command rm -rf "${INSTALL_DIR}/${OS}/boost"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		if [ -f "${SRC_DIR}/${BOOST_DIR}/bootstrap.sh" ]; then
			echo "Using existing isolated Boost source: ${SRC_DIR}/${BOOST_DIR}"
			return
		fi
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/boost_download.log" \
			wget -N "${BOOST_URL}" || return 1
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/boost_extract.log" \
			tar --skip-old-files -xjf "${BOOST_SRC_FILE}"
		return $?
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${SRC_DIR}"
		preview_command wget -N "${BOOST_URL}"
		preview_command tar --skip-old-files -xjf "${BOOST_SRC_FILE}"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		local config="${SRC_DIR}/boost-cross.jam"
		if [ "${DRY_RUN}" = true ]; then
			echo "DRY-RUN: write ${config}: using gcc : mingw : ${CXX} ;"
		else
			printf 'using gcc : mingw : %s ;\n' "${CXX}" > "${config}" || return 1
		fi
		run_cross_logged "${SRC_DIR}/${BOOST_DIR}" "${LOG_DIR}/boost_b2_build.log" \
			env -u CC -u CXX -u CFLAGS -u CXXFLAGS ./bootstrap.sh gcc
		return $?
	fi
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
			if [ "${DRY_RUN}" = true ]; then
				echo "DRY-RUN: write MSYS2 toolsets to ${HOME}/user-config.jam"
			else
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
		fi		
		########################################## W64 ##########################################
		;;		
	esac

	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${SRC_DIR}/${BOOST_DIR}"
		echo "DRY-RUN: ${BOOST_BOOTSTRAP}"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		# Match the existing Windows release/shared installation, not its misleading directory name.
		run_cross_logged "${SRC_DIR}/${BOOST_DIR}" "${LOG_DIR}/boost_b2_mingw_build.log" \
			./b2 "-j${NUMBER_OF_COMPILATIONS}" --ignore-site-config "--user-config=${SRC_DIR}/boost-cross.jam" \
			toolset=gcc-mingw target-os=windows architecture=x86 address-model=64 \
			variant=release threading=multi link=shared runtime-link=shared --layout=system cxxstd=17 \
			--with-atomic --with-chrono --with-container --with-date_time --with-exception \
			--with-filesystem --with-json --with-program_options --with-regex --with-thread \
			"--build-dir=${SRC_DIR}/boost-build" "--prefix=${BOOST_PREFIX}" install
		return $?
	fi
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
		if [ "${DRY_RUN}" = true ]; then
			preview_command mkdir -p "${SRC_DIR}/tmp/${COMPILER}"
		else
			mkdir -p ${SRC_DIR}/tmp/${COMPILER}
		fi
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
	
	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${SRC_DIR}/${BOOST_DIR}"
		echo "DRY-RUN: ${BOOST_B2}"
		return
	fi
	rm -f ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	
	cd "${SRC_DIR}/${BOOST_DIR}"  || exit	
	echo "Current directory: "$(pwd) | tee ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	
	echo "${BOOST_B2}" 2>&1 | tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	eval ${BOOST_B2}
}
