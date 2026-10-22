#!/bin/bash
# shellcheck disable=SC2046
# shellcheck disable=SC2086

# Run ShellCheck with: shellcheck -x build_devlib.sh
# -x follows sourced files

###############################################################
# Configure this depending on the versions/URLs of the packages
###############################################################
BOOST_URL=https://archives.boost.io/release/1.90.0/source/boost_1_90_0.tar.bz2
WXWIDGETS_URL=https://github.com/wxWidgets/wxWidgets/releases/download/v3.3.2/wxWidgets-3.3.2.tar.bz2

##############################################################################
# Change this to an other directory if you not want to use your home directory
##############################################################################

HOME=~

############################################
# Change this to other directories if needed
############################################

SRC_DIR=${SRC_DIR-${HOME}/devlib/src}
INSTALL_DIR=${INSTALL_DIR-${HOME}/devlib/}
LOG_DIR=${LOG_DIR-${HOME}/devlib/logs}

###########################
# Source the helper scripts
###########################

source modules/boost.sh
source modules/wxwidgets.sh

# build.sh must be the last because that actually contains the starting point
# which uses functions from the other modules
source modules/build.sh
