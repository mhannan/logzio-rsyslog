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
    echo "INFO" "Stopping execution. Bye bye..."
    exit 1
}

function usage {
	echo
	echo "Description:"
    echo "Install script, to monitor and forward logs to logz.io"
    echo "Version: $SCRIPT_VERSION" 
    echo
    echo "Usage:"
	echo "$(basename $0) -a auth_token -t type [-q suppress prompts] [-v verbose] [-c codec] [-h for help]"
	echo
	echo "-t(type) Allowed values:"
    for f in `find $LOGZ_DIR/configure_* -type f`; do
        KNOWN_TYPE=$(basename $f .sh | cut -f 2 -d '_')
        if [[ $KNOWN_TYPE != "utils" ]] && [[ $KNOWN_TYPE != "file" ]]; then
            echo "- $KNOWN_TYPE"
        fi
    done
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

#LOGZ_DIST_URL=https://dl.bintray.com/ofervelich/generic
#LOGZ_DIST=logzio-rsyslog.tar.gz


# ---------------------------------------- 
# User input variables
# ---------------------------------------- 
# the rsyslog instalation type 
export INSTALL_TYPE=""

# the user's authentication token, this is a mandatory input
export USER_TOKEN=""

# the log's file codec,default to text (allowed values text, json)
export CODEC_TYPE=""

# if this variable is set to false then suppress all prompts
export INTERACTIVE_MODE="true"

# Set the log level to debug (1=>debug 2=>info 3=>warn 4=>error)
export LOG_LEVEL=2

# logz.io working dir
export LOGZ_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# list all known types
export KNOWN_TYPES=()

for f in `find $LOGZ_DIR/configure_* -type f`; do
    KNOWN_TYPE=$(basename $f .sh | cut -f 2 -d '_')
    if [[ $KNOWN_TYPE != "utils" ]]; then
        KNOWN_TYPES+=( $KNOWN_TYPE )
    fi
done

options=()  # the buffer array for the parameters

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
            echo "[INFO]" "Log level is set to debug."
            ;;

        -q|--quiet)
            INTERACTIVE_MODE="false"
            echo "[INFO]" "Interactive mode is disabled."
            ;;

        -t|--type)
            if [ -n "$2" ]; then
                INSTALL_TYPE=$2
                echo "[INFO]" "Installation type is '$INSTALL_TYPE'."
                shift 2
                continue
            else
                echo "[ERROR]" "--type requires a non-empty option argument."
                usage 1
            fi
            ;;
        
        --hostname)
            if [ -n "$2" ]; then
                MACHINE_HOSTNAME=$2
                echo "[INFO]" "Hostname is '$MACHINE_HOSTNAME'."
                shift 2
                continue
            else
                echo "[ERROR]" "--hostname requires a non-empty option argument."
                usage 1
            fi
            ;;
        -c|--codec)
            if [ -n "$2" ]; then
                CODEC_TYPE=$2
                echo "[INFO]" "Log file codec is '$CODEC_TYPE'."
                shift 2
                continue
            fi
            ;;

        -a|--authtoken)
            if [ -n "$2" ]; then
                USER_TOKEN=$2
                echo "[INFO]" "User token is '$USER_TOKEN'."
                shift 2
                continue
            else
                echo "[ERROR]" "--authtoken requires a non-empty option argument."
                usage 1
            fi
            ;;

        --) # End of all options.
            options+=("$1")
            ;;
        *)  # Default case: If no more options then break out of the loop.
            options+=("$1")
            ;;
    esac

    shift

    if [ -z $1 ]; then
        break
    fi

done


# ---------------------------------------- 
# Setup dependencies
# ---------------------------------------- 

# include source
source $LOGZ_DIR/configure_utils.sh

# execution ...
if [ "$USER_TOKEN" != "" ] && [ "$INSTALL_TYPE" != "" ]; then
	
    # ensure valid codec
    if [[ "$CODEC_TYPE" != "json" ]]; then
        CODEC_TYPE="text"
    fi
    log "DEBUG" "File codec is: $CODEC_TYPE"


    # ---------------------------------------- 
    # Backwards computably
    # ---------------------------------------- 
    containsElement "${INSTALL_TYPE}" "${KNOWN_TYPES[@]}"
    
    # if $INSTALL_TYPE do not match, set install type to file and create addtional argument --tag with the value of the original install type. 
    if [ $? -ne 0 ]; then
        ADDITIONAL_ARGS="-tag ${INSTALL_TYPE}"
        export FILE_TAG=$INSTALL_TYPE
        INSTALL_TYPE="file"
    fi


    log "DEBUG" "File to execute: $LOGZ_DIR/configure_${INSTALL_TYPE}.sh"

    if [[ -f $LOGZ_DIR/configure_${INSTALL_TYPE}.sh ]]; then
        log "INFO" "Executing: configure ${INSTALL_TYPE}"
        
        # execute
        # and, make sure to pass $ADDITIONAL_ARGS!
        source $LOGZ_DIR/configure_${INSTALL_TYPE}.sh "${options[@]}" $ADDITIONAL_ARGS

        # To be on the safe side, let's restart again
        service_restart
    else
        log "ERROR" "Invalid install type: ${INSTALL_TYPE}"
        usage 1
    fi
    
    # cleanup
    rm -rf $LOGZ_DIR

else
    log "ERROR" "Please make sure that you pass user authentication token, and an install type."
	usage 1
fi

log "INFO" "Completed."
exit 0