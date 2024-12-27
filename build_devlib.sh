#!/bin/bash

# THIS IS AN ADAPTION OF THE BUILDSCRIPTS VERSION OF ROBOTWORLD
# Basically it is the robotworld script with other prefixes and 
# without the compilation of robotworld

# use ccache
# log for debug purposes
# export CCACHE_LOGFILE=/home/jkr/build/ccache.log
export PATH=/usr/lib/ccache:$PATH

# Boost is platform dependent, i.e. Windows or Linux/Unix/Mac(?) dependent. wxWidgets and APPLICATION
# live solely in Unix country...

# SRC_DIR: the directory where the source of all packages will be downloaded, unpacked and compiled
#          The path should be using the Unix convention, e.g. the directory should be '/' and NOT '\'.
#          Typically /home/$USER/src can be used

# PREFIX_DIR: the directory where Boost and wxWidgets will be installed. The path should be using the 
#             Unix convention, e.g. the directory be '/' and NOT '\'.
#             Typically /home/$USER/somedirectory can be used.
#             Note that the actual directory for Boost in Windows will be in MSYS2_ROOTDIR + PREFIX_DIR (next item).

# MSYS2_ROOTDIR: We prepend the unix-like PREFIX_DIR with the root of MSys2-directory for the Boost b2-compilation. 
#                Else Boost will be installed in a non-unix-path (typically drive_letter:\PREFIX_DIR) which breaks 
#                the compilation of APPLICATION. Or vice versa. Because I live in Linux country, guess who wins ;-)
#                Therefor Boost will end up in MSYS2_ROOTDIR + PREFIX_DIR. The paths should be using the Unix convention, 
#                e.g. the directory separator should be '/' and *NOT '\'*!
#                Therefor, if MSYS2_ROOTDIR=d:/msys64 and PREFIX_DIR=/home/$USER/devlib/w64 ,
#                then Boost will be installed in:    d:/msys64/home/$USER/devlib/w64 
#                In the compilation of the application only $PREFIX_DIR is used (unix compatibility)

# BOOST_URL: an URL for the Boost source
# WXWIDGETS_URL: an URL for the wxWidgets source
# APPLICATION_URL: an URL for the APPLICATION source. 
#                 If you use an ssh-connection you should have an ssh-key in place! See Stash-online docs.
#                 Not using a ssh-connection will lead to entering passwords...

####################################################################################
# Compile Boost, wxWidgets and application seperately or in any combination.
# To run the application Boost and wxWidgets must be available
# Any old version of Boost, wxWidgets and application are removed before compilation
####################################################################################

while [ $# -gt 0 ]
do
	case $1
	in
		all)
			do_boost=true
			do_wxwidgets=true
			do_application=true
			shift 1
   		;;

		boost)
			do_boost=true
			shift 1
		;;

		wxwidgets)
			do_wxwidgets=true
			shift 1
		;;
		
		configure)
			do_configure=true
			WXWIDGETS_PREFIX_BUILDTYPE=configure
			shift 1
		;;
		
		cmake)
			do_cmake=true
			WXWIDGETS_PREFIX_BUILDTYPE=cmake
			shift 1
		;;
		
		both)
			do_both=true
			WXWIDGETS_PREFIX_BUILDTYPE=both
			shift 1
		;;
		
		application)
			do_application=true
			shift 1
		;;

    	*)
      		echo "The arguments to use are: "
      		echo "all"
      		echo "boost"
      		echo "wxwidgets [configure|cmake|both]]"
      		echo "application"
	  		return 1
      		shift 1
    	;;
  	esac
done

APPLICATION_NAME=robotworld
	
#############################################################################
# Change this to another directory if you not want to use your home directory
#############################################################################
HOME=~

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################

BOOST_URL=https://boostorg.jfrog.io/artifactory/main/release/1.86.0/source/boost_1_86_0.tar.bz2
WXWIDGETS_URL=https://github.com/wxWidgets/wxWidgets/releases/download/v3.2.6/wxWidgets-3.2.6.tar.bz2
APPLICATION_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${APPLICATION_NAME}.git

######################################################################
# Determine OS and set the correct source and installation directories
######################################################################
  
OS=`uname -s | awk '{ print tolower($0) }'`
case ${OS} in
	linux*)
		########################################## Linux ##########################################
		SRC_DIR=${HOME}/devlib/src
		PREFIX_DIR=${HOME}/devlib/linux
		########################################## Linux ##########################################
		;;
	mingw64*)
		########################################### W64 ###########################################
		# Use a MSYS2 MinGW *64-bit* shell, *NOT* the MSYS2 MSYS shell!
		# Mind the drive letter in the MSYS2_ROOTDIR (your msys-64 may be on another drive)!!!
		SRC_DIR=${HOME}/devlib/src
		PREFIX_DIR=${HOME}/devlib/w64
		MSYS2_ROOTDIR=$(cd ~ ; pwd -W)
		MSYS2_ROOTDIR=$(echo ${MSYS2_ROOTDIR:0:9})
		########################################### W64 ###########################################
		;;
	darwin*)
		########################################## Darwin ##########################################
		SRC_DIR=${HOME}/devlib/src
		PREFIX_DIR=${HOME}/devlib/darwin
		########################################## Darwin ##########################################
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
echo "BOOST_URL: "${BOOST_URL}
echo "WXWIDGETS_URL: "${WXWIDGETS_URL}
echo "APPLICATION_URL: "${APPLICATION_URL}
echo "OS: "${OS}
echo "SRC_DIR: "${SRC_DIR}
echo "PREFIX_DIR: "${PREFIX_DIR}
echo "MSYS2_ROOTDIR: "${MSYS2_ROOTDIR}
echo "NUMBER_OF_COMPILATIONS: "${NUMBER_OF_COMPILATIONS}
echo "boost: "${do_boost}
echo "wxwidgets: "${do_wxwidgets}
echo "configure: "${do_configure}
echo "cmake: "${do_cmake}
echo "both: "${do_both}
echo "application: "${do_application}

#######################################################################################################################################3
# Hopefully no configuration needed below these lines
#######################################################################################################################################3

##########################################################################
# Create the directories: No checking of any kind is done...
# This depends on a Unix like command environment. Otherwise '/' is '\'...
##########################################################################
mkdir -p ${SRC_DIR}
mkdir -p ${PREFIX_DIR}

###################
# Boost compilation
###################
function compile_boost
{
	cd ${SRC_DIR} 

#########################################
# Boost needs a memory model from 1.68 up
#########################################

	BOOST_MEMORY_MODEL=`uname -m`
	if [ ${BOOST_MEMORY_MODEL} == 'x86_64' ]; then
		BOOST_MEMORY_MODEL=64
	else
		BOOST_MEMORY_MODEL=32
	fi

#############################################
# Determine the OS compilation environment 
#############################################

# Separate Linux and Darwin in anticipation for differences...
	case ${OS} in
	linux*)
		BOOST_PREFIX_DIR=$PREFIX_DIR
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.sh
		# NOTE: I suspect the "--prefix=$BOOST_PREFIX_DIR/boost.tagged" is moot for the compilation of bjam2/b2
		BOOST_BOOTSTRAP=".${BOOST_DIRECTORY_SEPARATOR}$BOOST_BOOTSTRAP_COMMAND gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged 2>&1 | tee -a boost_build.log"
		BOOST_B2=".${BOOST_DIRECTORY_SEPARATOR}b2 -j$NUMBER_OF_COMPILATIONS toolset=gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged --build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release address-model=${BOOST_MEMORY_MODEL} --layout=tagged --without-python --cxxflags="-std=c++17" install stage 2>&1 | tee -a boost_build.log"

		;;
	mingw*)
		# See introduction of the configuration.
		# Replace the '/' in the Unix path with '\' in the Windows path
		BOOST_PREFIX_DIR=$(echo "$MSYS2_ROOTDIR$PREFIX_DIR" | sed 's/\//\\/g')
		BOOST_DIRECTORY_SEPARATOR="\\"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.bat
		# On windows we need to use cmd instead of sh/bash
		BOOST_BOOTSTRAP="cmd //c .\"${BOOST_DIRECTORY_SEPARATOR}$BOOST_BOOTSTRAP_COMMAND gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged 2>&1 | tee -a boost_build.log\""
		BOOST_B2="cmd //c .\"${BOOST_DIRECTORY_SEPARATOR}b2 -j$NUMBER_OF_COMPILATIONS toolset=gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged --build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release address-model=$BOOST_MEMORY_MODEL --layout=tagged --without-python --cxxflags="-std=c++17" install stage 2>&1 | tee -a boost_build.log\""
		;;
	darwin*)
		BOOST_PREFIX_DIR=$PREFIX_DIR
		BOOST_DIRECTORY_SEPARATOR="/"
		BOOST_BOOTSTRAP_COMMAND=bootstrap.sh
		BOOST_BOOTSTRAP=".${BOOST_DIRECTORY_SEPARATOR}${BOOST_BOOTSTRAP_COMMAND} gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged 2>&1 | tee -a boost_build.log"
		BOOST_B2=".${BOOST_DIRECTORY_SEPARATOR}b2 -j${NUMBER_OF_COMPILATIONS} toolset=gcc --prefix=${BOOST_PREFIX_DIR}/boost.tagged --build-type=complete link=shared runtime-link=shared threading=multi,single variant=debug,release address-model=$BOOST_MEMORY_MODEL --layout=tagged --without-python --cxxflags="-std=c++17" install stage 2>&1 | tee -a boost_build.log"
		;;
	esac

	BOOST_SRC=${BOOST_URL##*/}
	BOOST_DIR=${BOOST_SRC%.tar.bz2}
	BOOST_PREFIX_DIR=$BOOST_PREFIX_DIR

	#########################
	# Remove any old versions
	#########################
	# source directory
	if [ -f "${SRC_DIR}/${BOOST_SRC}" ]; then
  		rm ${SRC_DIR}/${BOOST_SRC}
	fi
	# build directory
	if [ -d "${SRC_DIR}/${BOOST_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${BOOST_DIR}
	fi
	# installation directory
	if [ -d "${BOOST_PREFIX_DIR}/boost.tagged" ]; then
  		rm -rf ${BOOST_PREFIX_DIR}/boost.tagged
	fi

	#########################
	# Get, build and install it
	#########################
	wget ${BOOST_URL}
	tar xjf ${BOOST_SRC}
	cd ${BOOST_DIR}
	echo "${BOOST_BOOTSTRAP}" | tee boost_build.log
	eval ${BOOST_BOOTSTRAP}
	echo "${BOOST_B2}" | tee -a boost_build.log
	eval ${BOOST_B2}
}

#######################
# wxWidgets compilation
#######################

function compile_wxwidget_buildtype
{
	cd $SRC_DIR
	
	WXWIDGETS_PREFIX_DIR=${PREFIX_DIR} 
	WXWIDGETS_SRC=${WXWIDGETS_URL##*/} # translate the download url to wxwidgets-a.b.c.tar.bz2
	WXWIDGETS_DIR=${WXWIDGETS_SRC%.tar.bz2}  # translate the wxwidgets-a.b.c.tar.bz2 to wxwidgets-a.b.c
	BUILD_TYPE_DIRECTORY=$1

	if [ $1 = "configure" ] 
	then
		WXWIDGETS_CONFIGURE="../configure --with-gtk=3 --enable-debug --with-cxx=17 --prefix=${WXWIDGETS_PREFIX_DIR}/${BUILD_TYPE_DIRECTORY}/${WXWIDGETS_DIR} 2>&1 | tee -a wxwidgets_build.log"		
	fi 
	if [ $1 = "cmake" ] 
	then
		WXWIDGETS_CONFIGURE="cmake .. -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=${WXWIDGETS_PREFIX_DIR}/${BUILD_TYPE_DIRECTORY}/${WXWIDGETS_DIR} 2>&1 | tee -a wxwidgets_build.log"		
	fi 
	
	WXWIDGETS_MAKE="make -j${NUMBER_OF_COMPILATIONS} 2>&1 | tee  -a wxwidgets_build.log"
	WXWIDGETS_MAKE_INSTALL="make install 2>&1 | tee  -a wxwidgets_build.log"
	
	echo "WXWIDGETS_CONFIGURE = "$WXWIDGETS_CONFIGURE
	
	#########################
	# Remove any old versions
	#########################
	# source directory
	if [ -f "${SRC_DIR}/${WXWIDGETS_SRC}" ]; then
  		rm "${SRC_DIR}/${WXWIDGETS_SRC}"
	fi
	# build directory
	if [ -d "${SRC_DIR}/${WXWIDGETS_DIR}" ]; then
  		rm -rf ${SRC_DIR}/${WXWIDGETS_DIR}
	fi
	# installation directory
	if [ -d "${WXWIDGETS_PREFIX_DIR}/${WXWIDGETS_PREFIX_BUILDTYPE}/${WXWIDGETS_DIR}" ]; then
  		rm -rf ${WXWIDGETS_PREFIX_DIR}/${WXWIDGETS_PREFIX_BUILDTYPE}/${WXWIDGETS_DIR}
	fi	

	#########################
	# Get, build and install it
	#########################
	wget ${WXWIDGETS_URL}
	tar xjf ${WXWIDGETS_SRC}
	mkdir -p ${WXWIDGETS_DIR}/${OS}
	cd ${WXWIDGETS_DIR}/${OS}
	echo "${WXWIDGETS_CONFIGURE}" | tee wxwidgets_build.log
	eval ${WXWIDGETS_CONFIGURE}
	echo "${WXWIDGETS_MAKE}" | tee -a wxwidgets_build.log
	eval ${WXWIDGETS_MAKE}
	echo "${WXWIDGETS_MAKE_INSTALL}" | tee -a wxwidgets_build.log
	eval ${WXWIDGETS_MAKE_INSTALL}
}

function compile_wxwidget
{
	if [ "$WXWIDGETS_PREFIX_BUILDTYPE" = "configure" ] 
	then
		compile_wxwidget_buildtype configure		
	fi 
	if [ "$WXWIDGETS_PREFIX_BUILDTYPE" = "cmake" ] 
	then
		compile_wxwidget_buildtype cmake		
	fi 
	if [ "$WXWIDGETS_PREFIX_BUILDTYPE" = "both" ] 
	then
		compile_wxwidget_buildtype configure		
		compile_wxwidget_buildtype cmake
	fi 
}

################
# Do the work...
################
if [ "$do_boost" = "true" ] 
then
	compile_boost
fi 
if [ "$do_wxwidgets" = "true" ] 
then
	compile_wxwidget
fi 

echo $WXWIDGETS_PREFIX_BUILDTYPE
