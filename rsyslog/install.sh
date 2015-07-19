#!/bin/bash


# Copyright logz.io
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#exit on Control + C
trap ctrl_c INT

function ctrl_c()  {
    echo "INFO" "Stopping execution. Bay bay..."
    exit 1
}

function usage {
	echo
	echo "Description:"
    echo "Install script, to monitor and forward logs to logz.io"
    echo "Version: $SCRIPT_VERSION" 
    echo
    echo "Usage:"
	echo "$(basename $0) -a auth_token -t install_type [-q suppress prompts] [-v verbose] [-h for help]"
	echo
	echo "-t(install type) Allowed values:"
	echo "      1. linux"
	echo "      2. apache"
	echo "      3. nginx"
	echo "      4. file"
	echo

    exit $1
}

# ---------------------------------------- 
# validate that the user has root privileges
# ---------------------------------------- 
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] This script must be run as root."
   exit 1
fi

# ---------------------------------------- 
# Setup variables
# ---------------------------------------- 
SCRIPT_VERSION="1.0.0"

LOGZ_DIST_URL=https://dl.bintray.com/ofervelich/generic
LOGZ_DIST=logzio-rsyslog.tar.gz
export LOGZ_DIR=/tmp/logzio


# ---------------------------------------- 
# User input variables
# ---------------------------------------- 
export INSTALL_TYPE=""

# the user's authentication token, this is a mandatory input
export USER_TOKEN=""

# if this variable is set to false then suppress all prompts
export INTERACTIVE_MODE="true"

# Set the log level to debug (1=>debug 2=>info 3=>warn 4=>error)
export LOG_LEVEL=2


# ---------------------------------------- 
# Setup dependencies
# ---------------------------------------- 

# Ensure an empty logzio directory in the tmp folder.
rm -rf $LOGZ_DIR
mkdir -p $LOGZ_DIR

echo "[INFO] download script dependencies: $LOGZ_DIST ..."
# download distribution
curl -s -L -o $LOGZ_DIR/$LOGZ_DIST "$LOGZ_DIST_URL/$LOGZ_DIST"
# extract to logz tmp folder
tar -xzf $LOGZ_DIR/$LOGZ_DIST -C $LOGZ_DIR
# remove tarball
rm -f $LOGZ_DIR/$LOGZ_DIST
# ensure file are executable 
chmod -R +x $LOGZ_DIR/rsyslog
# update the logz dir to point to the location of the extracted tarball
export LOGZ_DIR=/tmp/logzio/rsyslog

# include source
source $LOGZ_DIR/configure_utils.sh



# ---------------------------------------- 
# script arguments
# ---------------------------------------- 
while :; do
    case $1 in
        -h|-\?|--help)
            usage 0
            ;;

        -v|--verbose)
			LOG_LEVEL=1
			log "INFO" "Log level is set to debug"
            ;;

        -q|--quite)
			INTERACTIVE_MODE="false"
			log "INFO" "Interactive mode mode is disabled"
            ;;

        -t|--type)
            if [ -n "$2" ]; then
				INSTALL_TYPE=$2
				log "INFO" "Installation type is '$INSTALL_TYPE'"
                shift 2
                continue
            else
                log "ERROR" "--type requires a non-empty option argument."
                usage 1
            fi
            ;;

        -a|--authtoken)
            if [ -n "$2" ]; then
                USER_TOKEN=$2
				log "INFO" "User token is '$USER_TOKEN'"
                shift 2
                continue
            else
                log "ERROR" "--authtoken requires a non-empty option argument."
                usage 1
            fi
            ;;   

        --) # End of all options.
            shift
            break
            ;;
        *)  # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done


if [ "$USER_TOKEN" != "" ] && [ "$INSTALL_TYPE" != "" ]; then
	# execute
    log "DEBUG" "File to execute: $LOGZ_DIR/configure_${INSTALL_TYPE}.sh"

    if [[ -f $LOGZ_DIR/configure_${INSTALL_TYPE}.sh ]]; then
        log "INFO" "Executing: configure ${INSTALL_TYPE}"
        source $LOGZ_DIR/configure_${INSTALL_TYPE}.sh

        # To be on the safe side, let's restart again
        service_restart
    else
        log "ERROR" "Invalid install type: ${INSTALL_TYPE}"
        usage 1
    fi
    
    # cleanup
    rm -rf $LOGZ_DIR

else
    log "ERROR" "Please make sure that you pass user authentication token, and an install type"
	usage 1
fi


exit 0