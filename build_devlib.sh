#!/bin/bash
# shellcheck disable=SC2046
# shellcheck disable=SC2086

# shellcheck command line : "shellcheck -x build_robotworld.sh"
# -x follows sourced files

########################################################
# The application that should be compiled by this script
########################################################

APPLICATION_NAME=robotworld

####################################################
# The library that should be compiled by this script
####################################################

MESSAGING_NAME=messaginglibrary

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################

BOOST_URL=https://archives.boost.io/release/1.86.0/source/boost_1_86_0.tar.bz2
WXWIDGETS_URL=https://github.com/wxWidgets/wxWidgets/releases/download/v3.2.6/wxWidgets-3.2.6.tar.bz2
MESSAGING_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${MESSAGING_NAME}.git
APPLICATION_URL=ssh://git@bitbucket.aimsites.nl:7999/esdd/${APPLICATION_NAME}.git

##############################################################################
# Change this to an other directory if you not want to use your home directory
##############################################################################

HOME=~

############################################
# Change this to other directories if needed
############################################

SRC_DIR=${HOME}/devlib/src
INSTALL_DIR=${HOME}/devlib/
LOG_DIR=${HOME}/devlib/logs

########################################################
# Source the helper scripts
########################################################

source modules/boost.sh
source modules/wxwidgets.sh
source modules/messaginglibrary.sh
source modules/robotworld.sh

# build.sh must be the last because that actually contains the starting point
# which uses functions from the other modules
source modules/build.sh
