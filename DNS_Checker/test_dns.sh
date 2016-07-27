#!/bin/bash
# Author Alastair Kerr
# Script for testing that DNS resolution is working on a given set of hosts
# Loop through given server list and check resolution of each target server works
# These tests rely on having passwordless SSH access to the hosts in the server list

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Default vars
SERVER_LIST="servers"
TARGET_LIST="targets"
CONNECTION_TIMEOUT=3

function usage {
    echo -e "${YELLOW}Usage: [-h (help)] [-s <server list file>] [-t <targets list file>] [-o <SSH timeout>]${NC}"
}

while [[ $# > 0 ]]
do
flag="$1"
case $flag in
    -h|--help)
    usage && exit 0
    shift
    ;;
    -s|--servers)
    SERVER_LIST="$2"
    echo -e "Read in ${YELLOW}${SERVER_LIST}${NC} as servers list location"
    shift
    ;;
    -t|--targets)
    TARGET_LIST="$2"
    echo -e "Read in ${YELLOW}${TARGET_LIST}${NC} as targets list location"
    shift
    ;;
    -o|--timeout)
    CONNECTION_TIMEOUT="$2"
    echo -e "Read in ${YELLOW}${CONNECTION_TIMEOUT}s${NC} as SSH connection timeout"
    shift
    ;;
    *)
    echo -e "${RED}Unknown flag `echo $flag | tr -d '-'`${NC}"
    usage && exit 2
esac
shift
done

# Interpret servers and targets to test 
SERVERS=()
SERVER_COUNT=0
TARGETS=()
TARGET_COUNT=0

grep -v '^$' ${SERVER_LIST} > "${SERVER_LIST}.tmp"
while read -r line
do
    SERVER_COUNT=$((SERVER_COUNT+1))
    SERVERS[${SERVER_COUNT}]="${line}"
done < "${SERVER_LIST}.tmp"

grep -v '^$' ${TARGET_LIST} > "${TARGET_LIST}.tmp"
while read -r line
do
    TARGET_COUNT=$((TARGET_COUNT+1))
    TARGETS[${TARGET_COUNT}]="${line}"
done < "${TARGET_LIST}.tmp"

rm -f "${SERVER_LIST}.tmp" "${TARGET_LIST}.tmp"

# Loop through servers, SSH in and test DNS resolution for each target
# Save result of each test to be output later
> results
COUNTER=0
TOTAL=$((SERVER_COUNT * TARGET_COUNT))
echo "Total checks to make: $TOTAL"
for (( i=1; i<=${SERVER_COUNT}; i++ )); do
    SERVER=${SERVERS[${i}]}

    # Scanning for SSH key - add if not already in known hosts
    SSHKEY=$(ssh-keyscan ${SERVER} 2> /dev/null)
    cat ~/.ssh/known_hosts | grep -q ${SERVER}
    if ! [ $? -eq 0 ]; then
        echo ${SSHKEY} >> ~/.ssh/known_hosts
    fi

    # SSH in and test DNS resolution for each target 
    for (( j=1; j<=${TARGET_COUNT}; j++ )); do
        TARGET=${TARGETS[${j}]}
        COMMAND="dig ${TARGET} +short"

        ssh -qno ConnectTimeout=${CONNECTION_TIMEOUT} "${SERVER}" "${COMMAND}" > tmp_result
        ec=$?

        if [ ${ec} -eq 255 ]; then
            echo -e "${RED}Failed to SSH into host ${SERVER}${NC}" >> results
        elif ! [ ${ec} -eq 0 ]; then
            echo -e "${RED}Unknown error executing check for ${SERVER} -> ${TARGET}${NC}" >> results
        else 
            RESULT_LENGTH=$(cat tmp_result | wc -l)
            if ! [ ${RESULT_LENGTH} -eq 1 ]; then
                echo -e "${RED}${SERVER} could not resolve ${TARGET}${NC}" >> results
            else
                echo -e "${GREEN}${SERVER} resolved ${TARGET} as $(cat tmp_result)${NC}" >> results
            fi
        fi

        # Tracking progress so far as percentage of rules checked
        COUNTER=$((COUNTER+1))
        PERCENTAGE=$(echo "(${COUNTER} / ${TOTAL}) * 100" | bc -l)
        echo -en "Processing $(printf %.0f ${PERCENTAGE})%\\r"
    done
done

rm -f tmp_result
echo -e "${YELLOW}\nFinished processing. Results:\n${NC}"
cat results

