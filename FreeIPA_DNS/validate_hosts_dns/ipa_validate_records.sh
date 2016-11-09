#!/bin/bash
# Author: Alastair Kerr
# Validate given hostname(s) have valid forward and reverse records
# You must have valid kerberos credentials - run `kinit` before executing this script
# Run this script on an IPA master, passing in raw hostnames only 

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

RESULTS_FILE="/tmp/ipa_dns_validation_results"


function usage {
    echo -e "${YELLOW}Usage:\n" \
            "    [-h]    List this help\n" \
            "    [-s]    Specify single host to check\n" \
            "    [-i]    Input file with list of hosts to check\n" \
            "    [-o]    Output file name (if not specified, a temp file is used)${NC}"
}

function getForwardRecordName {
    FWD_NAME=$(echo "$1" | sed 's/\..*$//')
}

function getForwardZoneName {
    FWD_ZONE=$(echo "$1" | sed 's/^[a-z0-9-]*\.//')
}

function getForwardARecord {
    FWD_IP=$(ipa dnsrecord-show $1 $2 2>/dev/null)
    if [ $? -ne 0 ]; then
        FUNC_STATUS=1
    else
        FWD_IP=$(echo "$FWD_IP" | awk '/A\ record:/ {print $3}')
        FUNC_STATUS=0
    fi
}

function getReverseZoneName {
    IP_PART_RVS=$(echo "$1" | awk -F '.' '{print $3,$2,$1}' OFS='.')
    RVS_ZONE=$(echo "${IP_PART_RVS}.in-addr.arpa")
}

function getReverseRecordName {
    RVS_NAME=$(echo "$1" | awk -F '.' '{print $4}')
}

function getReversePTRRecord {
    RVS_PTR=$(ipa dnsrecord-show $1 $2 2>/dev/null)
    if [ $? -ne 0 ]; then
        FUNC_STATUS=1
    else
        RVS_PTR=$(echo "$RVS_PTR" | awk '/PTR\ record:/ {print $3}')
        FUNC_STATUS=0
    fi
}

function outputPercentageCompleted {
    COUNTER=$((COUNTER+1))
    PERCENTAGE=$(echo "(${COUNTER} / ${TOTAL}) * 100" | bc -l)
    echo -en "Processing $(printf %.0f ${PERCENTAGE})%\\r"
}


# Read command line options
while [[ $# > 0 ]]
do
flag="$1"
case $flag in
    -h|--help)
        usage && exit 0
        ;;
    -s|--servername)
        INPUT_HOST="$2"
        shift
        ;;
    -i|--inputfile)
        INPUT_FILE="$2"
        shift
        ;;
    -o|--outputfile)
        RESULTS_FILE="$2"
        shift
        ;;
    *)
        echo -e "${RED}Unknown flag $(echo $flag | tr -d '-')${NC}"
        usage && exit 1
esac
shift
done    

# Validate user opts
if [ -z "$INPUT_HOST" ] && [ -z "$INPUT_FILE" ]; then 
    echo -e "${RED}You must specify either a single host or an input file with multiple hosts!${NC}"
    usage && exit 1
elif ! [ -z "$INPUT_HOST" ] && ! [ -z "$INPUT_FILE" ]; then
    echo -e "${RED}Please specify only one option [-i] or [-s]${NC}"
    usage && exit 1
elif ! [ -z "$INPUT_HOST" ]; then
    HOSTS_TO_CHECK="$INPUT_HOST"
elif ! [ -z "$INPUT_FILE" ]; then
    HOSTS_TO_CHECK=$(cat "$INPUT_FILE" | egrep -v '^$|^#.*') # Ignore empty lines and comments
else
    echo -e "${RED}Fell through unexpectedly! Exiting..${NC}" && exit 1
fi

# Iterate over each host, validating DNS entries and writing results to file
> "$RESULTS_FILE"
TOTAL=$(echo $HOSTS_TO_CHECK | wc -w)
COUNTER=0
for i in $HOSTS_TO_CHECK; do
    # Query A Record
    getForwardRecordName "$i"
    getForwardZoneName "$i"
    getForwardARecord "$FWD_ZONE" "$FWD_NAME"
    if [ "$FUNC_STATUS" -ne 0 ]; then
        echo -e "${RED}Host $i: A record could not be found${NC}" >> "${RESULTS_FILE}"
        outputPercentageCompleted
        continue
    fi

    # Query PTR record
    getReverseRecordName "$FWD_IP"
    getReverseZoneName "$FWD_IP"
    getReversePTRRecord "$RVS_ZONE" "$RVS_NAME"
    if [ "$FUNC_STATUS" -ne 0 ]; then
        echo -e "${RED}Host $i: PTR record for IP ${FWD_IP} could not be found${NC}" >> "${RESULTS_FILE}"
        outputPercentageCompleted
        continue
    fi

    # Compare and record results
    if [[ "$i" == "${RVS_PTR::-1}" ]]; then 
        echo -e "${GREEN}Host $i: Reverse and forward match for IP ${FWD_IP}${NC}" >> "${RESULTS_FILE}"
    else
        echo -e "${RED}Host $i: A Record ${FWD_IP}, but this IP's PTR record is ${RVS_PTR}${NC}" >> "${RESULTS_FILE}"
    fi

    # incrementing counter and tracking progress
    outputPercentageCompleted
done

echo -e "Finished: Results written to ${RESULTS_FILE}, and outputting to screen now:\n"
cat "$RESULTS_FILE"
