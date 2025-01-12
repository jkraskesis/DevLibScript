#!/bin/bash

# return value from function: https://stackoverflow.com/questions/17336915/return-value-in-a-bash-function

# THIS IS AN ADAPTION OF THE BUILDSCRIPTS VERSION OF ROBOTWORLD
# Basically it is the robotworld script with other prefixes and 
# without the compilation of robotworld

# Boost is platform dependent, i.e. Windows or Linux/Unix/Mac(?) dependent. wxWidgets and APPLICATION
# live solely in Unix country...

# SRC_DIR: the directory where the source of all packages will be downloaded, unpacked and compiled
#          The path should be using the Unix convention, e.g. the directory should be '/' and NOT '\'.
#          Typically /home/$USER/src can be used

# INSTALL_DIR: the directory where Boost and wxWidgets will be installed. The path should be using the 
#             		Unix convention, e.g. the directory be '/' and NOT '\'.
#	    	        Typically /home/$USER/somedirectory can be used.
#   	    	    Note that the actual directory for Boost in Windows will be in MSYS2_ROOTDIR + INSTALL_DIR (next item).
#
# MSYS2_ROOTDIR: We prepend the unix-like INSTALL_DIR with the root of MSys2-directory for the Boost b2-compilation. 
#                Else Boost will be installed in a non-unix-path (typically drive_letter:\INSTALL_DIR) which breaks 
#                the compilation of APPLICATION. Or vice versa. Because I live in Linux country, guess who wins ;-)
#                Therefor Boost will end up in MSYS2_ROOTDIR + INSTALL_DIR. The paths should be using the Unix convention, 
#                e.g. the directory separator should be '/' and *NOT '\'*!
#                Therefor, if MSYS2_ROOTDIR=d:/msys64 and INSTALL_DIR=/home/$USER/devlib/w64 ,
#                then Boost will be installed in:    d:/msys64/home/$USER/devlib/w64 
#                In the compilation of the application only $INSTALL_DIR is used (unix compatibility)

# BOOST_URL: an URL for the Boost source
# WXWIDGETS_URL: an URL for the wxWidgets source
# APPLICATION_URL: an URL for the APPLICATION source. 
#                 If you use an ssh-connection you should have an ssh-key in place! See Stash-online docs.
#                 Not using a ssh-connection will lead to entering passwords...

########################################################
# Handle the arguments
########################################################

vars=$(getopt -o ":o:b:c:h" --long "os:,buildtool:,compiler:,help": -- "$@")
eval set -- "$vars"

OS=`uname -s | awk '{ print tolower($0) }'`
echo "Auto detected ${OS} as operating system"
BUILDTOOL="configure"
echo "Auto determined ${BUILDTOOL} as buildtool"
COMPILER=$(readlink -f $(which cc))
if [[ $COMPILER == *gcc* ]]; then
	echo "Auto detected gcc as default cc compiler"
	COMPILER="gcc"
fi
if [[ $COMPILER == *clang* ]]; then
	echo "Auto detected clang as default cc compiler"
	COMPILER="clang"
fi

do_boost=false
do_wxwidgets=false
do_application=false
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
				
		application)
			do_application=true
		;;
		all)
			do_boost=true
			do_wxwidgets=true
			do_application=true
			do_all=true
		;;
	esac
	if [[ ${do_boost} == "true" && ${do_wxwidgets} == "true" && ${do_application} == "true" ]]; then
		do_all=true
	fi
}

while true; do
	case "$1" in
		-o|--os)
			OS=$2			
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
		-h|--help)
			echo "The arguments to use are: "
			echo "	-o | --os darwin|linux|mingw"
			echo "	-b | --buildtools configure|cmake|both"
			echo "	-c | --compiler gcc|clang|both"
			echo "	boost"
			echo "	wxwidgets"
			echo "	application"
			echo "	all (= boost && wxwidgets && application)"
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

########################################################
# The application that should be compiled by this script
########################################################

APPLICATION_NAME=robotworld

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################

BOOST_URL=https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.bz2
WXWIDGETS_URL=https://github.com/wxWidgets/wxWidgets/releases/download/v3.2.6/wxWidgets-3.2.6.tar.bz2
APPLICATION_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${APPLICATION_NAME}.git

#############################################################################
# Change this to another directory if you not want to use your home directory
#############################################################################

HOME=~

#######################################################################################################################################
# Hopefully no configuration needed below these lines
#######################################################################################################################################

SRC_DIR=${HOME}/devlib/src
INSTALL_DIR=${HOME}/devlib/
LOG_DIR=${SRC_DIR}/logs
mkdir -p ${LOG_DIR}

WXWIDGETS_SRC_FILE=${WXWIDGETS_URL##*/} # translates the download url to wxwidgets-a.b.c.tar.bz2	
WXWIDGETS_DIR=${WXWIDGETS_SRC_FILE%.tar.bz2}  # translates the wxwidgets-a.b.c.tar.bz2 to wxwidgets-a.b.c

BOOST_SRC_FILE=${BOOST_URL##*/} # translates the download url to boost_a_b_c_.tar.bz2
BOOST_DIR=${BOOST_SRC_FILE%.tar.bz2}  # translates the boost_a_b_c_.tar.bz2 to boost_a_b_c

APPLICATION_SRC_FILE="Tomptiedom: no source file" # application has no source file tar.bz2 
APPLICATION_DIR=${APPLICATION_NAME}

##########################################################################
# Use ccache. This must be done after the autodetection of the compiler
# because otherwise /usr/bin/ccache will be detected as the real compiler.
# Log for debug purposes
# export CCACHE_LOGFILE=/home/jkr/build/ccache.log
##########################################################################

export PATH=/usr/lib/ccache:$PATH

#######################################################################################
# Set the correct source and installation directories depending on the operating system
#######################################################################################  

case ${OS} in
	darwin*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################
		;&
	linux*)
		########################################## Linux ##########################################
		########################################## Linux ##########################################
		;;
	mingw64*)
		########################################### W64 ###########################################
		# Use a MSYS2 MinGW *64-bit* shell, *NOT* the MSYS2 MSYS shell!
		# Mind the drive letter in the MSYS2_ROOTDIR (your msys-64 may be on another drive)!!!
		MSYS2_ROOTDIR=$(cd ~ ; pwd -W) # pwd -W: print the win32 value of the physical directory (path including the drive letter), MingW extension. 
		MSYS2_ROOTDIR=$(echo ${MSYS2_ROOTDIR:0:9})
		########################################### W64 ###########################################
		;;
	*)
		OS="UNKNOWN:${uname_type}"
		echo "Cannot compile for an unknown os: "${OS} 
		exit
esac

# The number of processors that the compilations can use
NUMBER_OF_PROCESSORS=`grep -c ^processor /proc/cpuinfo`
if echo $NUMBER_OF_PROCESSORS | egrep -q '^[0-9]+$'; then
    NUMBER_OF_COMPILATIONS=$((${NUMBER_OF_PROCESSORS}-1))
else
    NUMBER_OF_COMPILATIONS=4
fi

#######################################################################################################################################3
# Print the configuration
#######################################################################################################################################3
echo "HOME: "${HOME}
echo "OS: "${OS}
echo "BUILDTOOL: "${BUILDTOOL}
echo "COMPILER: "${COMPILER}
echo "BOOST_URL: "${BOOST_URL}
echo "WXWIDGETS_URL: "${WXWIDGETS_URL}
echo "APPLICATION_URL: "${APPLICATION_URL}
echo "SRC_DIR: "${SRC_DIR}
echo "INSTALL_DIR: "${INSTALL_DIR}
echo "MSYS2_ROOTDIR: "${MSYS2_ROOTDIR}
echo "NUMBER_OF_COMPILATIONS: "${NUMBER_OF_COMPILATIONS}
echo "BUILDTOOL:"${BUILDTOOL}
echo "COMPILER: "${COMPILER}
echo "do_boost :"${do_boost}
echo "do_wxwidgets :"${do_wxwidgets}
echo "do_application :"${do_application}
echo "do_all :"${do_all}

##########################################################################
# Create the root directories: No checking of any kind is done...
# This depends on a Unix like command environment. Otherwise '/' is '\'...
##########################################################################
mkdir -p ${SRC_DIR}
mkdir -p ${INSTALL_DIR}

###################################################################
# Remove the source of Boost
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_boost_source
{
	# source file
	if [ -f "${SRC_DIR}/${BOOST_SRC_FILE}" ]; then
  		rm ${SRC_DIR}/${BOOST_SRC_FILE}
	fi
	# source and build directory
	if [ -d "${SRC_DIR}/${BOOST_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${BOOST_DIR}
	fi
}

###################################################################
# Remove all installations of Boost
################################################################### 
function remove_boost_installations
{
	echo "rm -rf ${INSTALL_DIR}/${OS}/boost.tagged"
	# installation directory
	if [ -d "${INSTALL_DIR}/${OS}/boost.tagged" ]; then
  		rm -rf ${INSTALL_DIR}/${OS}/boost.tagged
	fi
}

###################################################################
# Remove the downloaded source of wxWidgets
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_wxwidgets_source
{
	# source file
	if [ -f "${SRC_DIR}/${WXWIDGETS_SRC_FILE}" ]; then
  		rm "${SRC_DIR}/${WXWIDGETS_SRC_FILE}"
	fi
	# source and build directory
	if [ -d "${SRC_DIR}/${WXWIDGETS_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${WXWIDGETS_DIR}
	fi
}

#######################################
# Remove all installations of wxWidgets
#######################################
function remove_wxwidgets_installations
{
	declare -a BUILD_TOOLS=("configure" "cmake")
	
	for TOOL in "${BUILD_TOOLS[@]}"
	do
		echo "rm -rf ${INSTALL_DIR}/${OS}/${TOOL}/${WXWIDGETS_DIR}"
		if [ -d "${INSTALL_DIR}/${OS}/${TOOL}/${WXWIDGETS_DIR}" ]; then
  			rm -rf ${INSTALL_DIR}/${OS}/${TOOL}/${WXWIDGETS_DIR}
		fi
	done	
}

###################################################################
# Remove the source of the application
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_application_source
{
	# source directory
	if [ -d "${SRC_DIR}/${APPLICATION_DIR}" ]; then	
  		rm -rf "${SRC_DIR}/${APPLICATION_DIR}"
	fi
}

###################################################################
# Remove the sources
# This also removes all compilation artifacts, NOT the installation
################################################################### 
function remove_sources
{
	remove_boost_source
	remove_wxwidgets_source 
	remove_application_source 
}

###################################################################
# Remove the installed files
################################################################### 
function remove_installations
{
	remove_boost_installations  
	remove_wxwidgets_installations   
}

############################
# Download and extract Boost
############################
function download_and_extract_boost
{
	cd ${SRC_DIR}
	# Only download the local file does not exist, or if the remote file is newer
	wget -N ${BOOST_URL}
	# Do not overwrite any existing files
	tar --skip-old-files -xjf ${BOOST_SRC_FILE}
}

################################
# Download and extract wxWidgets
################################
function download_and_extract_wxwidgets
{
	cd ${SRC_DIR}
	# Only download the local file does not exist, or if the remote file is newer
	wget -N ${WXWIDGETS_URL}
	# Do not overwrite any existing files
	tar --skip-old-files -xjf ${WXWIDGETS_SRC_FILE}
}

#######################
# Clone the application
#######################
function clone_application
{
	cd ${SRC_DIR}
	git clone $APPLICATION_URL
}

#######################
# Get all sources
#######################
function get_sources
{
	download_and_extract_boost 
	download_and_extract_wxwidgets 
	clone_application 
}

###################################################################
# Remove the installed stuff
################################################################### 
function remove_installations
{
	remove_boost_installations 
	remove_wxwidgets_installations 
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
		BOOST_INSTALLATION_DIR=$(echo "$MSYS2_ROOTDIR$INSTALLATION_DIR" | sed 's/\//\\/g')
		BOOST_DIRECTORY_SEPARATOR="\\"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.bat
		# On windows we need to use cmd instead of sh/bash
		BOOST_BOOTSTRAP="cmd //c .\"${BOOST_DIRECTORY_SEPARATOR}$BOOST_BOOTSTRAP_COMMAND gcc --prefix=${BOOST_INSTALLATION_DIR}/boost.tagged 2>&1 | tee -a ${LOG_DIR}/boost_b2_build.log\""
		########################################## W64 ##########################################
		;;		
	esac

	#########################
	# Get, build and install it
	#########################
	cd ${SRC_DIR}/${BOOST_DIR}
	rm -f ${LOG_DIR}/boost_b2_build.log
	echo "${BOOST_BOOTSTRAP}" | tee ${LOG_DIR}/boost_b2_build.log
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
		;&
		
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
		install stage 2>&1 | tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
		EOF
		)
		########################################## Linux ##########################################
		;;
	mingw*)
		########################################## W64 ##########################################
		# See introduction of the configuration.
		# Replace the '/' in the Unix path with '\' in the Windows path
		BOOST_INSTALL_DIR=$(echo "$MSYS2_ROOTDIR$INSTALL_DIR" | sed 's/\//\\/g')
		BOOST_DIRECTORY_SEPARATOR="\\"
		BOOST_B2=$(cat <<-EOF
		"cmd //c 
		.\"${BOOST_DIRECTORY_SEPARATOR}b2 
		-j$NUMBER_OF_COMPILATIONS 
		toolset=${COMPILER} 
		--build-dir=${SRC_DIR}/${BOOST_DIR}/build/${OS}/${COMPILER} 
		--stagedir=${SRC_DIR}/${BOOST_DIR}/stage/${OS}/${COMPILER} 
		--prefix=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged 
		--build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release --layout=tagged --without-python --without-mpi 
		--cxxflags="-std=c++17" 
		install stage 2>&1 | tee -a ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log\""
		EOF
		)
		########################################## W64 ##########################################		
		;;
	esac

	#########################
	# build and install it
	#########################
	cd "$SRC_DIR/${BOOST_DIR}"
	rm -f ${LOG_DIR}/boost_${OS}_b2_${COMPILER}_build.log
	echo "${BOOST_B2}" | tee -a boost_${OS}_b2_${COMPILER}_build.log
	eval ${BOOST_B2}
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
		CXX="/usr/bin/g++"		
	fi 
	if [ "${COMPILER}" = "clang" ] 
	then
		CXX="/usr/bin/clang++"
	fi 

	if [ ${BUILDTOOL} = "configure" ] 
	then
		WXWIDGETS_CONFIGURE="CXX=${CXX} ../../../configure --with-gtk=3 --enable-debug --with-cxx=17 --prefix=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log"		
	fi 
	if [ ${BUILDTOOL} = "cmake" ] 
	then
		WXWIDGETS_CONFIGURE="CXX=${CXX} cmake ../../.. -G \"Unix Makefiles\" -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR} 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log"		
	fi
	
	mkdir -p "$SRC_DIR/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	cd "$SRC_DIR/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_config.log
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
	
	WXWIDGETS_MAKE="make -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log"
	WXWIDGETS_MAKE_INSTALL="make install 2>&1 | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log"	
	
	cd "$SRC_DIR/${WXWIDGETS_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	
	rm -f ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	echo "${WXWIDGETS_MAKE}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${WXWIDGETS_MAKE}
	echo "${WXWIDGETS_MAKE_INSTALL}" | tee -a ${LOG_DIR}/wxwidgets_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${WXWIDGETS_MAKE_INSTALL}
}

#########################
# Application compilation
#########################

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
		APPLICATION_CONFIGURE="CXX=${CXX} ../../../configure --with-wx-config=${INSTALL_DIR}/${OS}/wxwidgets/${BUILDTOOL}/${COMPILER}/${WXWIDGETS_DIR}/bin/wx-config --with-boost=${INSTALL_DIR}/${OS}/boost/${COMPILER}/boost.tagged --with-cxx=17 2>&1 | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log"		
	fi 
	if [ ${BUILDTOOL} = "cmake" ] 
	then
		APPLICATION_CONFIGURE="CMAKE_PREFIX_PATH=/home/jkr/devlib/${OS}/boost/${COMPILER}/boost.tagged/lib/cmake:/home/jkr/devlib/${OS}/wxwidgets/cmake/${COMPILER}/${WXWIDGETS_DIR}/lib/cmake CXX=${CXX} cmake ../../.. -G \"Unix Makefiles\" -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/${OS}/${APPLICATION_NAME}/${BUILDTOOL}/${COMPILER}/${APPLICATION_NAME} 2>&1 | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log"
	fi

	# update the Autotools files for local things
	if [ "${BUILDTOOL}" = "configure" ] 
	then
		cd ${SRC_DIR}/${APPLICATION_DIR}
		./autogen.sh
	fi 

	mkdir -p "$SRC_DIR/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"
	cd "$SRC_DIR/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"

	rm -f ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_config.log
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

	APPLICATION_MAKE="make -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log"
	
	cd "$SRC_DIR/${APPLICATION_DIR}/${OS}/${BUILDTOOL}/${COMPILER}"

	rm -f ${LOG_DIR}/${APPLICATION}_${OS}_${BUILD_TOOL_DIR}_${COMPILER}_build.log
	echo "${APPLICATION_MAKE}" | tee -a ${LOG_DIR}/${APPLICATION_NAME}_${OS}_${BUILDTOOL}_${COMPILER}_build.log
	eval ${APPLICATION_MAKE}
}

################
# Do the work...
################



#remove_sources 
#remove_installations 
#get_sources

if [ "$do_boost" = "true" ] 
	then
	
	download_and_extract_boost

	# we us a gcc compiled version of b2 for all compilations	
	configure_boost "gcc"

	if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ] 
	then
		compile_boost gcc		
	fi 
	if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ] 
	then
		compile_boost clang		
	fi 	
fi 

if [ "$do_wxwidgets" = "true" ] 
then

	download_and_extract_wxwidgets

	if [ "${BUILDTOOL}" = "configure" ] || [ "${BUILDTOOL}" = "both" ] 
	then
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_wxwidgets configure gcc ${OS}			
			compile_wxwidgets configure gcc ${OS}		
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_wxwidgets configure clang ${OS}			
			compile_wxwidgets configure clang ${OS}		
		fi 	
	fi 

	if [ "${BUILDTOOL}" = "cmake" ] || [ "${BUILDTOOL}" = "both" ] 
	then
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_wxwidgets cmake gcc ${OS}			
			compile_wxwidgets cmake gcc ${OS}		
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_wxwidgets cmake clang ${OS}			
			compile_wxwidgets cmake clang ${OS}		
		fi 	
	fi 
fi 

if [ "$do_application" = "true" ] 
then

	clone_application 

	if [ "${BUILDTOOL}" = "configure" ] || [ "${BUILDTOOL}" = "both" ] 
	then
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_application configure gcc ${OS}			
			compile_application configure gcc ${OS}		
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_application configure clang ${OS}			
			compile_application configure clang ${OS}		
		fi 	
	fi 

	if [ "${BUILDTOOL}" = "cmake" ] || [ "${BUILDTOOL}" = "both" ] 
	then
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_application cmake gcc ${OS}			
			compile_application cmake gcc ${OS}		
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ] 
		then
			configure_application cmake clang ${OS}			
			compile_application cmake clang ${OS}		
		fi 	
	fi 	
fi 

echo $BUILD_TOOL
