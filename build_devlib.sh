#!/bin/bash
# shellcheck disable=SC2046
# shellcheck disable=SC2086

# THIS IS AN ADAPTION OF THE BUILDSCRIPTS VERSION OF ROBOTWORLD
# Basically it is the robotworld script with other SRC and INSTALL
# directories

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

########################################################
# The library that should be compiled by this script
########################################################

MESSAGING_NAME=messaginglibrary

########################################################
# The application that should be compiled by this script
########################################################

APPLICATION_NAME=robotworld

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################

BOOST_URL=https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.bz2
WXWIDGETS_URL=https://github.com/wxWidgets/wxWidgets/releases/download/v3.2.6/wxWidgets-3.2.6.tar.bz2
MESSAGING_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${MESSAGING_NAME}.git
APPLICATION_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${APPLICATION_NAME}.git

#############################################################################
# Change this to an other directory if you not want to use your home directory
#############################################################################

HOME=~

############################################
# Change this to other directories if needed
############################################

SRC_DIR=${HOME}/devlib/src
INSTALL_DIR=${HOME}/devlib/
LOG_DIR=${HOME}/devlib/logs

#######################################################################################################################################
# Hopefully no configuration needed below these lines
#######################################################################################################################################

########################################################
# Source the helper scripts
########################################################

source modules/boost.sh
source modules/wxwidgets.sh
source modules/messaginglibrary.sh
source modules/robotworld.sh

########################################################
# Handle the arguments
########################################################

vars=$(getopt -o ":o:b:c:d:h" --long "os:,buildtool:,compiler:,debug:,help": -- "$@")
eval set -- "$vars"

OS=$(uname -s | awk '{ print tolower($0) }')
echo "Auto detected ${OS} as operating system"
BUILDTOOL="configure"
echo "Auto determined ${BUILDTOOL} as buildtool"
COMPILER=$(readlink -f "$(which cc)")
if [[ $COMPILER == *gcc* ]]; then
	echo "Auto detected gcc as default cc compiler"
	COMPILER="gcc"
fi
if [[ $COMPILER == *clang* ]]; then
	echo "Auto detected clang as default cc compiler"
	COMPILER="clang"
fi
DEBUG="true"
echo "Auto detected DEBUG as true"

do_boost=false
do_wxwidgets=false
do_messaging=false
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

		messaging)
			do_messaging=true
		;;
		
		application)
			do_application=true
		;;
		all)
			do_boost=true
			do_wxwidgets=true
			do_messaging=true
			do_application=true
			do_all=true
		;;
	esac
	if [[ ${do_boost} == "true" && ${do_wxwidgets} == "true" && ${do_messaging} == "true" && ${do_application} == "true" ]]; then
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
		-d|--debug)
			DEBUG=$2
			shift 2
			;;
		-h|--help)
			echo "The arguments to use are: "
			echo "	-o | --os darwin|linux|mingw"
			echo "	-b | --buildtool configure|cmake|both"
			echo "	-c | --compiler gcc|clang|both"
			echo "	-d | --debug true|false"
			echo "	boost"
			echo "	wxwidgets"
			echo "	messaging"
			echo "	application"
			echo "	all (= boost && wxwidgets && messaging && application)"
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

BOOST_SRC_FILE=${BOOST_URL##*/} # translates the download url to boost_a_b_c_.tar.bz2
BOOST_DIR=${BOOST_SRC_FILE%.tar.bz2}  # translates the boost_a_b_c_.tar.bz2 to boost_a_b_c

WXWIDGETS_SRC_FILE=${WXWIDGETS_URL##*/} # translates the download url to wxwidgets-a.b.c.tar.bz2
WXWIDGETS_DIR=${WXWIDGETS_SRC_FILE%.tar.bz2}  # translates the wxwidgets-a.b.c.tar.bz2 to wxwidgets-a.b.c

#MESSAGING_SRC_FILE="Tomptiedom: no source file for Messaging" # application has no source file tar.bz2 
MESSAGING_DIR=${MESSAGING_NAME}

#APPLICATION_SRC_FILE="Tomptiedom: no source file for ${APPLICATION_NAME}" # application has no source file tar.bz2 
APPLICATION_DIR=${APPLICATION_NAME}

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

case ${OS} in
	darwin*)
		########################################## Darwin ##########################################
		########################################## Darwin ##########################################
		;&
	linux*)
		########################################## Linux ##########################################
		set_ccache /usr/lib/ccache
		
		########################################## Linux ##########################################
		;;
	mingw64*)
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

# The number of processors that the compilations can use
NUMBER_OF_PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
if echo ${NUMBER_OF_PROCESSORS} | grep -E -q '^[0-9]+$'; then
    NUMBER_OF_COMPILATIONS=$((NUMBER_OF_PROCESSORS-1))
else
    NUMBER_OF_COMPILATIONS=4
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
echo "APPLICATION_URL: "${APPLICATION_URL}
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
echo "do_messaging :"${do_messaging}
echo "do_application :"${do_application}
echo "do_all :"${do_all}
echo "MESSAGING_NAME :"${MESSAGING_NAME}
echo "APPLICATION_NAME :"${APPLICATION_NAME}
echo "BOOST_DIR :"${BOOST_DIR}
echo "WXWIDGETS_DIR :"${WXWIDGETS_DIR}
echo "MESSAGING_DIR :"${MESSAGING_DIR}
echo "APPLICATION_DIR :"${APPLICATION_DIR}

##########################################################################
# Create the root directories: No checking of any kind is done...
# This depends on a Unix like command environment. Otherwise '/' is '\'...
##########################################################################
function create_directories
{
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
	remove_wxwidgets_source
	
	remove_wxwidgets_installations
	
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

if [ "$do_messaging" = "true" ]
then
	remove_messaging_source

	remove_messaging_installations
	
	clone_messaging 

	if [ "${BUILDTOOL}" = "configure" ] || [ "${BUILDTOOL}" = "both" ]
	then
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="--enable-development=yes"
		else
			DEBUG_ARGS="--enable-development=no"
		fi	
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ]
		then
			configure_messaging configure gcc ${OS}
			compile_messaging configure gcc ${OS}
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ]
		then
			configure_messaging configure clang ${OS}
			compile_messaging configure clang ${OS}
		fi 	
	fi 

	if [ "${BUILDTOOL}" = "cmake" ] || [ "${BUILDTOOL}" = "both" ]
	then
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=DEBUG"
		else
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=RELEASE"
		fi	
		if [ "${COMPILER}" = "gcc" ] || [ "${COMPILER}" = "both" ]
		then
			configure_messaging cmake gcc ${OS}
			compile_messaging cmake gcc ${OS}
		fi 
		if [ "${COMPILER}" = "clang" ] || [ "${COMPILER}" = "both" ]
		then
			configure_messaging cmake clang ${OS}
			compile_messaging cmake clang ${OS}
		fi 	
	fi 	
fi 

if [ "$do_application" = "true" ]
then
	remove_application_source

	remove_messaging_installations
	
	clone_application 

	if [ "${BUILDTOOL}" = "configure" ] || [ "${BUILDTOOL}" = "both" ]
	then
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="--enable-development=yes"
		else
			DEBUG_ARGS="--enable-development=no"
		fi	
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
		if [ "${DEBUG}" = "true" ]
		then
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=DEBUG"
		else
			DEBUG_ARGS="-DCMAKE_BUILD_TYPE=RELEASE"
		fi	
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
