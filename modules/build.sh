#!/usr/bin/env bash

########################################################
# Handle the arguments
########################################################

vars=$(getopt -o ":o:b:c:d:h" --long "os:,buildtool:,compiler:,debug:,help,target:,dry-run" -- "$@") || {
	echo "Invalid options or missing option value. Use --help for usage." >&2
	exit 1
}
eval set -- "$vars"

# Robust OS detection: normalize common uname -s values to one of
# linux | mingw | macos (maps Darwin -> macos). Fall back to lowercase
# uname value for unknown platforms.
UNAME_S=$(uname -s)
case "${UNAME_S}" in
  Linux*) OS=linux ;;
  Darwin*) OS=macos ;;
  MINGW*|MSYS*|CYGWIN*) OS=mingw ;;
  *) OS=$(echo "${UNAME_S}" | tr '[:upper:]' '[:lower:]') ;;
esac
echo "Auto detected ${OS} as operating system"
BUILD_OS=${OS}
TARGET_TRIPLET=
DRY_RUN=false
OS_EXPLICIT=false

BUILDTOOL="configure"
echo "Auto determined ${BUILDTOOL} as buildtool"
COMPILER=unknown
if COMPILER_MACROS=$(cc -dM -E -x c /dev/null); then
	if [[ ${COMPILER_MACROS} == *'define __clang__ '* ]]; then
		COMPILER=clang
	elif [[ ${COMPILER_MACROS} == *'define __GNUC__ '* ]]; then
		COMPILER=gcc
	fi
	echo "Auto detected ${COMPILER} as default cc compiler"
else
	echo "Cannot detect default cc compiler; specify --compiler gcc or clang." >&2
fi
DEBUG="true"
echo "Auto detected DEBUG as true"

do_boost=false
do_wxwidgets=false
do_all=false

function handle_argument
{
	case $1 in
		boost)
			do_boost=true
		;;

		wxwidgets)
			do_wxwidgets=true
		;;

		all)
			do_boost=true
			do_wxwidgets=true
			do_all=true
		;;
		*)
			echo "Unsupported project: $1. Choose boost, wxwidgets or all." >&2
			exit 1
		;;
	esac
	if [[ ${do_boost} == "true" && ${do_wxwidgets} == "true" ]]; then
		do_all=true
	fi
}

while true; do
	case "$1" in
		-o|--os)
			OS=$2
			OS_EXPLICIT=true
			shift 2
			;;
		-b|--buildtool)
			BUILDTOOL=$2
			shift 2
			;;
		-c|--compiler)
			COMPILER=$2
			shift 2
			;;
		-d|--debug)
			DEBUG=$2
			shift 2
			;;
		--target)
			TARGET_TRIPLET=$2
			shift 2
			;;
		--dry-run)
			DRY_RUN=true
			shift
			;;
		-h|--help)
			echo "The arguments to use are: "
 			echo "	-o | --os macos|linux|mingw"
			echo "	-b | --buildtool configure|cmake|both"
			echo "	-c | --compiler gcc|clang|both"
			echo "	-d | --debug true|false"
			echo "	--target x86_64-w64-mingw32 (GCC crosscompiler)"
			echo "	--dry-run (show commands without running them)"
			echo "	boost"
			echo "	wxwidgets"
			echo "	all (= boost && wxwidgets)"
			exit 1
		;;
		--) 
			shift ;
			break 
			;;
		*) 
			echo "Unrecognised argument: ${1} ${2}!"
			exit 1
			;;
	esac
done
for arg in "${@}"; do
	handle_argument "$arg"
done

if [ -z "${SRC_DIR}" ] || [ -z "${INSTALL_DIR}" ] || [ -z "${LOG_DIR}" ]; then
	echo "SRC_DIR, INSTALL_DIR and LOG_DIR must not be empty." >&2
	exit 1
fi

case ${OS} in
	linux|mingw|macos) ;;
	*) echo "Unsupported OS: ${OS}" >&2; exit 1 ;;
esac
case ${BUILDTOOL} in
	configure|cmake|both) ;;
	*) echo "Unsupported buildtool: ${BUILDTOOL}" >&2; exit 1 ;;
esac
case ${COMPILER} in
	gcc|clang|both) ;;
	*) echo "Unsupported compiler: ${COMPILER}" >&2; exit 1 ;;
esac
case ${DEBUG} in
	true|false) ;;
	*) echo "Unsupported debug value: ${DEBUG}" >&2; exit 1 ;;
esac

CROSS_COMPILING=false
TARGET_OS=${OS}
if [ -n "${TARGET_TRIPLET}" ]; then
	if [ "${BUILD_OS}" != linux ] || [ "${TARGET_TRIPLET}" != x86_64-w64-mingw32 ] ||
		[ "${COMPILER}" != gcc ] ||
		{ [ "${OS_EXPLICIT}" = true ] && [ "${OS}" != mingw ]; }; then
		echo "Cross builds require Linux, --target x86_64-w64-mingw32 and --compiler gcc (without a conflicting --os)." >&2
		exit 1
	fi
	CROSS_COMPILING=true
	TARGET_OS=mingw
	CXX=${TARGET_TRIPLET}-g++
	for tool in "${CXX}" gcc g++ wget tar bzip2 tee; do
		command -v "${tool}" >/dev/null || {
			echo "Missing build tool: ${tool}" >&2
			exit 1
		}
	done
	if [ "${do_wxwidgets}" = true ]; then
		wx_tools=("${TARGET_TRIPLET}-gcc" "${TARGET_TRIPLET}-windres")
		[ "${BUILDTOOL}" = configure ] || wx_tools+=(cmake ninja)
		[ "${BUILDTOOL}" = cmake ] || wx_tools+=(make "${TARGET_TRIPLET}-ar" "${TARGET_TRIPLET}-ranlib")
		for tool in "${wx_tools[@]}"; do
			command -v "${tool}" >/dev/null || {
				echo "Missing wxWidgets build tool: ${tool}" >&2
				exit 1
			}
		done
	fi
	if [ "$("${CXX}" -dumpmachine)" != "${TARGET_TRIPLET}" ]; then
		echo "Crosscompiler does not target ${TARGET_TRIPLET}." >&2
		exit 1
	fi
	LOG_DIR=${LOG_DIR}/cross/${TARGET_TRIPLET}
	BOOST_PREFIX=${INSTALL_DIR}/windows/boost/mingw/boost.tagged
	WXWIDGETS_PREFIX=${INSTALL_DIR}/windows/wxwidgets/cmake/mingw/${WXWIDGETS_URL##*/}
	WXWIDGETS_PREFIX=${WXWIDGETS_PREFIX%.tar.bz2}
	CROSS_TOOLCHAIN=$(pwd)/toolchains/mingw-gcc.cmake
	if [ "${do_boost}" = true ] && { [ -e "${BOOST_PREFIX}" ] || [ -L "${BOOST_PREFIX}" ]; }; then
		echo "Refusing to overwrite ${BOOST_PREFIX}. Use a separate INSTALL_DIR." >&2
		exit 1
	fi
	if [ "${do_wxwidgets}" = true ]; then
		for wx_tool in configure cmake; do
			[ "${BUILDTOOL}" = "${wx_tool}" ] || [ "${BUILDTOOL}" = both ] || continue
			prefix=${INSTALL_DIR}/windows/wxwidgets/${wx_tool}/mingw/${WXWIDGETS_URL##*/}
			prefix=${prefix%.tar.bz2}
			if [ -e "${prefix}" ] || [ -L "${prefix}" ]; then
				echo "Refusing to overwrite ${prefix}. Use a separate INSTALL_DIR." >&2
				exit 1
			fi
		done
	fi
fi

function preview_command
{
	printf 'DRY-RUN:'
	printf ' %q' "$@"
	printf '\n'
}

function run_cross_logged
{
	local directory=$1 log=$2
	shift 2
	if [ "${DRY_RUN}" = true ]; then
		preview_command cd "${directory}"
		preview_command "$@"
		echo "DRY-RUN: log to ${log}"
	else
		(
			set -o pipefail
			cd "${directory}" || exit 1
			"$@" 2>&1 | tee "${log}"
		) || {
			echo "Cross build failed; see ${log}." >&2
			return 1
		}
	fi
}

BOOST_SRC_FILE=${BOOST_URL##*/} # translates the download url to boost_a_b_c_.tar.bz2
BOOST_DIR=${BOOST_SRC_FILE%.tar.bz2}  # translates the boost_a_b_c_.tar.bz2 to boost_a_b_c

WXWIDGETS_SRC_FILE=${WXWIDGETS_URL##*/} # translates the download url to wxwidgets-a.b.c.tar.bz2
WXWIDGETS_DIR=${WXWIDGETS_SRC_FILE%.tar.bz2}  # translates the wxwidgets-a.b.c.tar.bz2 to wxwidgets-a.b.c

##########################################################################
# Use ccache. This must be done after the autodetection of the compiler
# because otherwise /usr/bin/ccache will be detected as the real compiler.
# Log for debug purposes
# export CCACHE_LOGFILE=/home/jkr/build/ccache.log
##########################################################################

function set_ccache
{
	local CCACHE_PATH=${1}

	export PATH=${CCACHE_PATH}:$PATH
	# log for debug purposes
	#export CCACHE_LOGFILE=/home/jkr/build/ccache.log
	# more info, more! 
	#export DISTCC_VERBOSE=1
	# instruct ccache to use distcc
	# export CCACHE_PREFIX=distcc
	# rely on avahi as specified in /etc/default/distcc to find the slaves instead of using the environmental variable
	#export DISTCC_HOSTS="+zeroconf"
	# log for debug purpses
	#export DISTCC_VERBOSE=1
}

#######################################################################################
# Set the correct source and installation directories depending on the operating system
#######################################################################################  

case ${BUILD_OS} in
	macos*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################
		;;
	linux*)
		########################################## Linux ##########################################
		set_ccache /usr/lib/ccache
		
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################### W64 ###########################################
		set_ccache /usr/lib/ccache/bin
		
		# MSYS2_ROOTDIR points to the directory with "home" in it, i.e. "/" in Linux. In windows format:
		# e.e. c:\msys64, with backslashes!
		# Use a MSYS2 MinGW *64-bit* shell, *NOT* the MSYS2 MSYS shell!
		# Mind the drive letter in the MSYS2_ROOTDIR (your msys-64 may be on another drive)!!!
		MSYS2_ROOTDIR=$(cd ~ ; pwd -W) # pwd -W: print the win32 value of the physical directory (path including the drive letter), MingW extension. 
		MSYS2_ROOTDIR=$(echo ${MSYS2_ROOTDIR:0:9})
		########################################### W64 ###########################################
		;;
	*)
		OS="UNKNOWN: $(uname -a)"
		echo "Cannot compile for an unknown os: ""${OS}"
		exit
esac

########################################################
# The number of processors that the compilations can use
########################################################

# The number of processors that the compilations can use
if [ -z "${NUMBER_OF_COMPILATIONS+x}" ]; then
	NUMBER_OF_PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
	if echo ${NUMBER_OF_PROCESSORS} | grep -E -q '^[0-9]+$' && [ "${NUMBER_OF_PROCESSORS}" -gt 1 ]; then
		NUMBER_OF_COMPILATIONS=$((NUMBER_OF_PROCESSORS-1))
	else
		NUMBER_OF_COMPILATIONS=4
	fi
fi
if ! [[ "${NUMBER_OF_COMPILATIONS}" =~ ^[1-9][0-9]*$ ]]; then
	echo "NUMBER_OF_COMPILATIONS must be a positive integer." >&2
	exit 1
fi

#######################################################################################################################################
# Print the configuration
#######################################################################################################################################
echo "HOME: "${HOME}
echo "OS: "${OS}
echo "BUILDTOOL: "${BUILDTOOL}
echo "COMPILER: "${COMPILER}
echo "BOOST_URL: "${BOOST_URL}
echo "WXWIDGETS_URL: "${WXWIDGETS_URL}
echo "SRC_DIR: "${SRC_DIR}
echo "INSTALL_DIR: "${INSTALL_DIR}
echo "LOG_DIR: "${LOG_DIR}
echo "MSYS2_ROOTDIR: "${MSYS2_ROOTDIR}
echo "NUMBER_OF_COMPILATIONS: "${NUMBER_OF_COMPILATIONS}
echo "BUILDTOOL:"${BUILDTOOL}
echo "COMPILER: "${COMPILER}
echo "DEBUG: "${DEBUG}
echo "do_boost :"${do_boost}
echo "do_wxwidgets :"${do_wxwidgets}
echo "do_all :"${do_all}
echo "BOOST_DIR :"${BOOST_DIR}
echo "WXWIDGETS_DIR :"${WXWIDGETS_DIR}
echo "BUILD_OS: ${BUILD_OS}"
echo "TARGET_OS: ${TARGET_OS}"
echo "TARGET_TRIPLET: ${TARGET_TRIPLET}"
echo "CROSS_COMPILING: ${CROSS_COMPILING}"
echo "DRY_RUN: ${DRY_RUN}"
if [ "${CROSS_COMPILING}" = true ]; then
	echo "BOOST_PREFIX: ${BOOST_PREFIX}"
	echo "CXX: ${CXX}"
fi

##########################################################################
# Create the root directories: No checking of any kind is done...
# This depends on a Unix like command environment. Otherwise '/' is '\'...
##########################################################################
function create_directories
{
	if [ "${DRY_RUN}" = true ]; then
		preview_command mkdir -p "${SRC_DIR}" "${INSTALL_DIR}" "${LOG_DIR}"
		return
	fi
	if [ "${CROSS_COMPILING}" = true ]; then
		mkdir -p "${SRC_DIR}" "${INSTALL_DIR}" "${LOG_DIR}" || exit 1
		return
	fi
	mkdir -p ${SRC_DIR}
	mkdir -p ${INSTALL_DIR}
	mkdir -p ${LOG_DIR}
}

################
# Do the work...
################

# create the directory structure
create_directories

if [ "$do_boost" = "true" ]
	then

	remove_boost_source
	
	remove_boost_installations

	download_and_extract_boost || exit 1

	# we us a gcc compiled version of b2 for all compilations
	#configure_boost "gcc"
	configure_boost "clang" || exit 1

	if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ]
	then
		compile_boost gcc || exit 1
	fi 
	if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ]
	then
		compile_boost clang || exit 1
	fi
fi

if [ "$do_wxwidgets" = "true" ]
then
	remove_wxwidgets_source
	
	remove_wxwidgets_installations
	
	download_and_extract_wxwidgets || exit 1

	if [ "${BUILDTOOL}" = "configure" ] || [ "${BUILDTOOL}" = "both" ]
	then
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="--enable-debug"
		else
			DEBUG_ARGS="---disable-debug"
		fi
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ]
		then
			configure_wxwidgets configure gcc ${OS} || exit 1
			compile_wxwidgets configure gcc ${OS} || exit 1
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ]
		then
			configure_wxwidgets configure clang ${OS}
			compile_wxwidgets configure clang ${OS}
		fi 	
	fi 

	if [ "${BUILDTOOL}" = "cmake" ] || [ "${BUILDTOOL}" = "both" ]
	then
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo"
		else
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=Release"
		fi
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ]
		then
			configure_wxwidgets cmake gcc ${OS} || exit 1
			compile_wxwidgets cmake gcc ${OS} || exit 1
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ]
		then
			configure_wxwidgets cmake clang ${OS}
			compile_wxwidgets cmake clang ${OS}
		fi 	
	fi 
fi 
