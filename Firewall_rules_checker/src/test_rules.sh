#!/bin/bash
# Main script to run to test firewall rules
# Reads in source, destination and ports to test from config
# Interpret config and loop over, testing each connection and compiling results
# Optional args -i <config file> (default is 'config')
#
# This script uses telnet with timeouts as not all servers have netcat installed
# A better alternative solution would've used: nc -w <timeout> -z <destination> <port>
#
# These tests rely on having passwordless SSH access to the source hosts 

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Default config vars
CONFIG_FILE="config"
CONFIG_FILE_OUT="${CONFIG_FILE}_out"
RESULTS_OUT="test_results"
TIMEOUT=3
RESOLVE_CHECK="true"

function usage {
    echo -e "${YELLOW}-i: input file, -t: telnet timeout, -r: set false to ignore destination nslookup check (default true)${NC}"
    echo -e "${YELLOW}Usage: [-i <config file>] [-t <timeout (seconds)>] [-r true/false]${NC}"
}

while [[ $# > 0 ]]
do
flag="$1"
case $flag in
    -h|--help)
    usage && exit 0
    shift
    ;;
    -i|--config)
    CONFIG_FILE="$2"
    CONFIG_FILE_OUT="${CONFIG_FILE}_out"
    echo -e "Read in ${YELLOW}${CONFIG_FILE}${NC} as config file location"
    shift
    ;;
    -t|--timeout)
    TIMEOUT="$2"
    echo -e "Read in ${YELLOW}${TIMEOUT}${NC}s as timeout"
    shift
    ;;
    -r|--resolve)
    if ! [[ "$2" = "true" ]] && ! [[ "$2" = "false" ]]; then
        echo -e "${RED}-r flag only accepts true/false as args. Got: ${2}${NC}"
        exit 1
    fi
    RESOLVE_CHECK="$2"
    shift
    ;;
    *)
    echo -e "${RED}Unknown flag `echo $flag | tr -d '-'`${NC}"
    usage && exit 1
esac
shift
done

echo -e "Enforce destination resolution check: ${YELLOW}${RESOLVE_CHECK}${NC}"

# Call python script to interpret and rewrite config in a more useable format
./rewrite_config.py -i ${CONFIG_FILE} -o ${CONFIG_FILE_OUT}
if ! [ $? -eq 0 ]; then
    echo -e "${RED}There was an error interpreting the provided config, exiting..${NC}"
    exit 1
fi

# Read in interpreted config file, ssh into source and test access to port on destination address
echo -e "${YELLOW}Testing firewall rules now.. (this may take some time)${NC}"
> ${RESULTS_OUT}
while read -r line
do
    echo -n "."

    RULE_ARR=()
    while IFS=',' read -ra VALUES; do
        count=1
        for j in "${VALUES[@]}"; do
            RULE_ARR[${count}]=${j}
            count=$((count+1))
        done
    done <<< "${line}"

    SOURCE=${RULE_ARR[1]}
    DEST=${RULE_ARR[2]}
    PORT=${RULE_ARR[3]}
    RULE="${SOURCE} -> ${DEST}:${PORT}"

    # Scanning for SSH key - add if not already in known hosts
    SSHKEY=$(ssh-keyscan ${SOURCE} 2> /dev/null)
    cat ~/.ssh/known_hosts | grep -q ${SOURCE}
    if ! [ $? -eq 0 ]; then
        echo ${SSHKEY} >> ~/.ssh/known_hosts
    fi

    # Confirm destination can be resolved
    if [[ "${RESOLVE_CHECK}" = "true" ]]; then
        ssh -qn ${SOURCE} "nslookup ${DEST} > /dev/null 2>&1"
        if ! [ $? -eq 0 ]; then
            echo -e "${RED}${RULE} ERROR - Could not resolve destination (use '-r false' arg to override)" >> ${RESULTS_OUT}
            continue
        fi
    fi

    # Build commands to execute on remote host and save result based on exit status 
    COMMAND="echo QUIT > quit; timeout ${TIMEOUT}s telnet ${DEST} ${PORT} < quit; echo EXIT_STATUS; rm -f quit"
    COMMAND=$(echo ${COMMAND} | sed s/EXIT_STATUS/\$\?/g)
    ssh -qn ${SOURCE} ${COMMAND} > tmp_result 2>&1

    # Save rule success/ failure message based on result of commands executed
    EXIT_STATUS=$(tail -n 1 tmp_result)
    if [ "${EXIT_STATUS}" = "124" ]; then
        echo -e "${RED}${RULE} FAILED - Exceeded telnet timeout${NC}" >> ${RESULTS_OUT}
    elif [ "${EXIT_STATUS}" = "127" ]; then
        echo -e "${RED}Could not run test on host ${SOURCE}: Telnet/ timeout may not be available${NC}" >> ${RESULTS_OUT}
    elif [ "${EXIT_STATUS}" = "1" ]; then
        cat tmp_result | grep -qi "Connected"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${RULE} PASSED${NC}" >> ${RESULTS_OUT}
        else
            echo -e "${GREEN}${RULE} PASSED ${YELLOW}- but service refused connection${NC}" >> ${RESULTS_OUT}
        fi
    else
        echo ${EXIT_STATUS} | grep -qi "Connection refused"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}${RULE} PASSED ${YELLOW}- but service refused connection${NC}" >> ${RESULTS_OUT}
        else
            echo ${EXIT_STATUS} | grep -qi "Connection closed"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}${RULE} PASSED" >> ${RESULTS_OUT}
            else
                echo -e "${RED}Unknown result for ${RULE}: Exited with '${EXIT_STATUS}'${NC}" >> ${RESULTS_OUT}
            fi
        fi
    fi
done < ${CONFIG_FILE_OUT}

# Cleanup and output results
rm -f tmp_result ${CONFIG_FILE_OUT}

echo -e "\n${GREEN}The script successfully executed${NC}\n"
echo -e "Results (saved to '${RESULTS_OUT}'):\n"
cat ${RESULTS_OUT}
