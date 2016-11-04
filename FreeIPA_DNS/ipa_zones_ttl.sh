#!/bin/bash
# Author: Alastair Kerr
# Query or manipulate TTL settings for all FreeIPA DNS zones
# User option -a to apply chosen operation to all zones
# Pass a file with -i containing 1 zone per line to apply chosen operation to just these
#
# Example usages
# ./ipa_zones_ttl.sh -a -l -f
# List all zones and their TTL, do not ask for confirmation
#
# ./ipa_zones_ttl.sh -i my_zones -s 21600
# Set all zones from file 'my_zones' to 21600 seconds TTL. Asks for confirmation
#
# ./ipa_zones_ttl.sh -a -r
# Remove explicit TTL value from all zones (defaults to 24 hours). Asks for confirmation


YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Max amount of LDAP results to return
SIZELIMIT=2500

function usage {
    echo -e "${YELLOW}Usage:\n" \
            "    [-h]      List this help\n" \
            "    [-f]      Force: Skip user validation step\n" \
            "    [-m INT]  Max amount of zones LDAP search will return\n" \
            "    -i FILE   Pass file with list of zones to run on\n" \
            "    -a        Apply to all zones\n" \
            "    -s INT    Set zones' TTL to <INT>\n" \
            "    -l        List zones' TTLs\n" \
            "    -r        Remove explicit TTLs for zones\n${NC}"
}

function userValidation {
    read -r -p "Will run $1 on $2. Proceed? [Y/N] " response
    response=${response,,}
    if ! [[ "$response" =~ ^(yes|y)$ ]]; then
        echo -e "${YELLOW}Exiting..${NC}" && exit 0
    fi
}

function isValidPositiveInteger {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        validInteger=0
    else
        validInteger=1
    fi
}

function setSizeLimit {
    isValidPositiveInteger "$1"
    if [[ "$validInteger" -eq 0 ]]; then
        SIZELIMIT="$1"
    else
        echo -e "${RED}PARAMETER ERROR: Not a positive integer: ${1}${NC}"
        usage && exit 1
    fi
}

function getAllZones {
    FREEIPA_ZONES=$(ipa dnszone-find --sizelimit=$SIZELIMIT \
        | awk '/Zone\ name:\ [a-z]/ {print $3}' | sort)
}

function setAllZonesTTL {
    for i in $FREEIPA_ZONES;
    do
        ipa dnszone-mod "$i" --ttl="$TTL" >/dev/null 2>&1
        echo "Set: ${i} => ${TTL} seconds TTL"
    done
    exit 0
}

function listAllZonesTTL {
    for i in $FREEIPA_ZONES; 
    do
        TTL=$(ipa dnszone-show --all $i | grep "Time to live")
        if [[ $? -eq 0 ]]; then
            echo "$(echo $TTL | awk -F ': ' '{print $2}') seconds TTL for $i"
        else
            echo "No explicit TTL set for $i"
        fi
    done
}

function removeAllZonesTTL {
    echo -e "${YELLOW}Emptying TTL field for all specified zones, this may take some time..${NC}"
    for i in $FREEIPA_ZONES;
    do
        QUERY=$(ipa dnszone-show --all $i | grep "Time to live")
        if [[ $? -eq 0 ]]; then
            TTL=$(echo $QUERY | awk -F ': ' '{print $2}')
            ipa dnszone-mod "$i" --delattr dNSTTL="$TTL" >/dev/null 2>&1
            echo "Removed TTL for $i"
        else
            echo "Already no explicit TTL set for $i"
        fi
    done
    exit 0
}


# Call appropriate method based on user args
NUMOPTS=0
while [[ $# > 0 ]]
do
flag="$1"
case $flag in 
    -h|--help)
        usage && exit 0
        ;;
    -f|--force)
        FORCE=true
        ;;
    -m|--max-ldap)
        setSizeLimit "$2"
        shift
        ;;
    -i|--input-file)
        INPUT_FILE="$2"
        ls "$INPUT_FILE" >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}PARAMETER ERROR: Input file '${INPUT_FILE}' could not be found${NC}"
            exit 1
        fi
        shift
        ;;
    -a|--apply-to-all)
        INPUT_ALL=true
        ;;
    -s|--set-zones-ttl)
        NUMOPTS=$((NUMOPTS+1))
        TTL="$2"
        isValidPositiveInteger "$TTL"
        if [[ "$validInteger" -eq 0 ]]; then
            OPT_SET=true
        else
            echo -e "${RED}PARAMETER ERROR: Not a positive integer: ${TTL}${NC}"
            usage && exit 1
        fi
        shift
        ;;
    -l|--list-zones-ttl)
        NUMOPTS=$((NUMOPTS+1))
        OPT_LIST=true
        ;;
    -r|--remove-zones-ttl)
        NUMOPTS=$((NUMOPTS+1))
        OPT_REMOVE=true
        ;;
    *)
        echo -e "${RED}Unknown flag $(echo $flag | tr -d '-')${NC}"
        usage && exit 1
esac
shift
done


# Discover or read zones to apply operation to
if [ -z "$INPUT_FILE" ] && [ -z "$INPUT_ALL" ]; then
    echo -e "${RED}ERROR: Please specify an input option [-a] or [-i <file>]${NC}"
    usage && exit 1
elif ! [ -z "$INPUT_FILE" ] && ! [ -z "$INPUT_ALL" ]; then
    echo -e "${RED}ERROR: Please specify only one of the input options [-a] or [-i <file>]${NC}"
elif ! [ -z "$INPUT_ALL" ]; then
    getAllZones
    ZONES_MSG="all zones"
else
    FREEIPA_ZONES=$(cat $INPUT_FILE)
    ZONES_MSG="zones from input file '$INPUT_FILE'"
fi


# Apply user chosen operation
if [ "$NUMOPTS" -eq 0 ]; then
    echo -e "${RED}ERROR: Please specify an operation: set, list or remove.${NC}"
    usage && exit 1
elif [ "$NUMOPTS" -gt 1 ]; then
    echo -e "${RED}ERROR: Please specify only one operation: set, list or remove.${NC}"
elif ! [ -z "$OPT_SET" ]; then
    if [ -z "$FORCE" ]; then
        userValidation "'set zone TTL'" "$ZONES_MSG"
    fi
    setAllZonesTTL "$TTL"
elif ! [ -z "$OPT_LIST" ]; then
    if [ -z "$FORCE" ]; then
        userValidation "'list zone TTL'" "$ZONES_MSG"
    fi
    listAllZonesTTL
elif ! [ -z "$OPT_REMOVE" ]; then
    if [ -z "$FORCE" ]; then
        userValidation "'remove zone TTL'" "$ZONES_MSG"
    fi
    removeAllZonesTTL
fi


echo -e "\n${GREEN}All operations completed${NC}"
