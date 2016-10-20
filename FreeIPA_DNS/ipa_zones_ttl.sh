#!/bin/bash
# Author: Alastair Kerr
# Query or manipulate TTL settings for all FreeIPA DNS zones

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Max amount of LDAP results to return
SIZELIMIT=2500

function usage {
    echo -e "${YELLOW}Usage:\n" \
            "    [-h]     List this help\n" \
            "    [-m INT] Max amount of zones LDAP search will return\n" \
            "    -s INT   Set all zones' TTL to <INT>\n" \
            "    -l       List all zones' TTLs\n" \
            "    -r       Remove explicit TTLs for all zones\n${NC}"
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
    TTL="$1"
    isValidPositiveInteger "$TTL"
    if [[ "$validInteger" -eq 0 ]]; then
        getAllZones
        for i in $FREEIPA_ZONES;
        do
            ipa dnszone-mod "$i" --ttl="$TTL" >/dev/null 2>&1
            echo "Set: ${i}"
        done
        exit 0
    else
        echo -e "${RED}PARAMETER ERROR: Not a positive integer: ${TTL}${NC}"
        usage && exit 1
    fi
}

function listAllZonesTTL {
    getAllZones
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
    echo -e "${YELLOW}Emptying TTL field for all zones, this may take some time..${NC}"
    getAllZones
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
while [[ $# > 0 ]]
do
flag="$1"
case $flag in 
    -h|--help)
        usage && exit 0
        shift
        ;;
    -m|--max-ldap)
        setSizeLimit "$2"
        shift
        ;;
    -s|--set-zones-ttl)
        setAllZonesTTL "$2" && exit 0
        shift
        ;;
    -l|--list-zones-ttl)
        listAllZonesTTL && exit 0
        shift
        ;;
    -r|--remove-zones-ttl)
        removeAllZonesTTL && exit 0
        shift
        ;;
    *)
        echo -e "${RED}Unknown flag $(echo $flag | tr -d '-')${NC}"
        usage && exit 1
esac
shift
done

echo -e "${RED}ERROR: Please specify an option${NC}"
usage && exit 1
