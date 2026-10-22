#!/usr/bin/env bash

###################################################################
# Remove the downloaded source of wxWidgets
# This also removes all compilation artifacts, NOT the installation
###################################################################
function remove_wxwidgets_source
{
	if [ "${CROSS_COMPILING}" = true ]; then
		echo "Reusing isolated wxWidgets sources: ${SRC_DIR}/${WXWIDGETS_DIR}"
		return
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command rm -f "${SRC_DIR}/${WXWIDGETS_SRC_FILE}"
		preview_command rm -rf "${SRC_DIR}/${WXWIDGETS_DIR}"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		return
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command rm -rf "${INSTALL_DIR}/${OS}/wxwidgets"
		return
	fi
	if [ -d "${INSTALL_DIR}/${OS}/wxwidgets" ]; then
			rm -rf ${INSTALL_DIR}/${OS}/wxwidgets
	fi
}

################################
# Download and extract wxWidgets
################################
function download_and_extract_wxwidgets
{
	if [ "${CROSS_COMPILING}" = true ]; then
		if [ -f "${SRC_DIR}/${WXWIDGETS_DIR}/CMakeLists.txt" ]; then
			echo "Using existing isolated wxWidgets source: ${SRC_DIR}/${WXWIDGETS_DIR}"
			return
		fi
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/wxwidgets_download.log" \
			wget -N "${WXWIDGETS_URL}" || return 1
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/wxwidgets_extract.log" \
			tar --skip-old-files -xjf "${WXWIDGETS_SRC_FILE}"
		return $?
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${SRC_DIR}"
		preview_command wget -N "${WXWIDGETS_URL}"
		preview_command tar --skip-old-files -xjf "${WXWIDGETS_SRC_FILE}"
		return
	fi
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
	if [ "${CROSS_COMPILING}" = true ]; then
		local prefix=${INSTALL_DIR}/windows/wxwidgets/${BUILDTOOL}/mingw/${WXWIDGETS_DIR}
		if [ "${BUILDTOOL}" = configure ]; then
			local build_triplet
			if [ "${DRY_RUN}" = true ]; then
				preview_command sh "${SRC_DIR}/${WXWIDGETS_DIR}/config.guess"
				build_triplet='<output-of-config.guess>'
				preview_command mkdir -p "${SRC_DIR}/wxwidgets-configure"
			else
				build_triplet=$(sh "${SRC_DIR}/${WXWIDGETS_DIR}/config.guess") || return 1
				mkdir -p "${SRC_DIR}/wxwidgets-configure" || return 1
			fi
			local debug_option=--disable-debug
			[ "${DEBUG}" != true ] || debug_option=--enable-debug
			run_cross_logged "${SRC_DIR}/wxwidgets-configure" "${LOG_DIR}/wxwidgets_configure_config.log" \
				env PKG_CONFIG_LIBDIR= PKG_CONFIG_PATH= CC="${TARGET_TRIPLET}-gcc" CXX="${CXX}" \
				AR="${TARGET_TRIPLET}-ar" RANLIB="${TARGET_TRIPLET}-ranlib" WINDRES="${TARGET_TRIPLET}-windres" \
				"${SRC_DIR}/${WXWIDGETS_DIR}/configure" "--build=${build_triplet}" "--host=${TARGET_TRIPLET}" \
				--with-msw --with-cxx=17 --enable-shared --disable-tests "${debug_option}" "--prefix=${prefix}"
			return $?
		fi
		local build_type=Release
		[ "${DEBUG}" != true ] || build_type=RelWithDebInfo
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/wxwidgets_cmake_config.log" \
			env PKG_CONFIG_LIBDIR= PKG_CONFIG_PATH= cmake \
			-S "${SRC_DIR}/${WXWIDGETS_DIR}" -B "${SRC_DIR}/wxwidgets-cmake" -G Ninja \
			"-DCMAKE_TOOLCHAIN_FILE=${CROSS_TOOLCHAIN}" \
			"-DCMAKE_BUILD_TYPE=${build_type}" "-DCMAKE_INSTALL_PREFIX=${WXWIDGETS_PREFIX}" \
			-DCMAKE_CXX_STANDARD=17 -DwxBUILD_TOOLKIT=msw -DwxBUILD_SHARED=ON \
			-DwxBUILD_SAMPLES=OFF -DwxBUILD_TESTS=OFF
		return $?
	fi
	
	case ${OS} in
	linux*)
		########################################## Linux ##########################################
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################## W64 ##########################################
		 export CMAKE_POLICY_VERSION_MINIMUM=3.5
		########################################## W64 ##########################################
		;;
	darwin*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################
		;;
	esac	
	
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
		WXWIDGETS_CONFIGURE=$(cat <<-EOF
									CXX=${COMPILATION_CXX}
									../../../configure 
									--with-cxx=17
									${DEBUG_ARGS} 
									--prefix=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 
									2>&1 
									| tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi 
	
	if [ ${BUILDTOOL} = "cmake" ]
	then
		WXWIDGETS_CONFIGURE=$(cat <<-EOF
									cmake 
									../../.. 
									-G Ninja 
									-DCMAKE_CXX_COMPILER=${COMPILATION_CXX}
									-DCMAKE_CXX_STANDARD=17
									${DEBUG_ARGS} 
									-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 
									2>&1 
									| tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log 
									EOF
									)
	fi
	
	if [ "${DRY_RUN}" = true ]; then
		preview_command mkdir -p "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
		preview_command cd "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
		echo "DRY-RUN: ${WXWIDGETS_CONFIGURE}"
		return
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
	if [ "${CROSS_COMPILING}" = true ]; then
		if [ "${BUILDTOOL}" = configure ]; then
			run_cross_logged "${SRC_DIR}/wxwidgets-configure" "${LOG_DIR}/wxwidgets_configure_build.log" \
				make "-j${NUMBER_OF_COMPILATIONS}" || return 1
			run_cross_logged "${SRC_DIR}/wxwidgets-configure" "${LOG_DIR}/wxwidgets_configure_install.log" \
				make install
			return $?
		fi
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/wxwidgets_cmake_build.log" \
			cmake --build "${SRC_DIR}/wxwidgets-cmake" --parallel "${NUMBER_OF_COMPILATIONS}" || return 1
		run_cross_logged "${SRC_DIR}" "${LOG_DIR}/wxwidgets_cmake_install.log" \
			cmake --install "${SRC_DIR}/wxwidgets-cmake"
		return $?
	fi
	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
		if [ "${BUILDTOOL}" = configure ]; then
			preview_command make "-j${NUMBER_OF_COMPILATIONS}"
			preview_command make install
		else
			preview_command ninja -v "-j${NUMBER_OF_COMPILATIONS}"
			preview_command ninja -v install
		fi
		return
	fi
	
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	
	cd "${SRC_DIR}/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}" || exit
	echo "Current directory: " $(pwd) | tee ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	
	if [ ${BUILDTOOL} = "configure" ]
	then
		MAKE_COMMAND="make"
	fi 
	
	if [ ${BUILDTOOL} = "cmake" ]
	then
		MAKE_COMMAND="ninja -v"
	fi

	WXWIDGETS_MAKE="${MAKE_COMMAND} -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log"
	echo "${WXWIDGETS_MAKE}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${WXWIDGETS_MAKE}
	
	WXWIDGETS_MAKE_INSTALL="${MAKE_COMMAND} install 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log"
	echo "${WXWIDGETS_MAKE_INSTALL}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_install.log
	eval ${WXWIDGETS_MAKE_INSTALL}
}
