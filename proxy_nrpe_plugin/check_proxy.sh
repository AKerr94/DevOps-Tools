#!/bin/bash
# Author: Alastair Kerr
#
# NRPE plugin to check if a proxy is working, using wget
# Example usage:
# ./check_proxy.sh -p 3129 -w myproxyserver.com -e https://endpoint.com

# Default config vars
CHK_PORT=3128
CHK_TIMEOUT=10 # timeout request after this many seconds
CHK_REMOVE_ARTIFACT=false
CHK_CMD=""


function usage {
    echo -e "Usage:\n" \
        "    -w <proxy address> - IP or resolveable FQDN\n" \
        "    -e <endpoint>      - Webpage or artifact to request\n" \
        "    [-p <port>]        - Port to connect to proxy on; default 3128\n" \
        "    [-o <output>]      - Filename to save output as; default use endpoint filename\n" \
        "    [-t <integer>]     - Request times out after this many seconds; default 10s\n" \
        "    [-r]               - Remove file after you download it"
}

function addVarToCmd {
    CHK_CMD="${CHK_CMD}$1"
}

while [[ $# > 0 ]]
do
flag="$1"
case $flag in
    -h|--help)
        usage && exit 0
    shift
    ;;
    -p|--port)
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
            echo "ARG ERROR: Invalid port number '$2'!"
            usage && exit 3
        fi
        CHK_PORT="$2"
    shift
    ;;
    -o|--output)
        CHK_OUTPUT="$2"
    shift
    ;;
    -w|--proxy)
        CHK_PROXY="$2"
    shift
    ;;
    -e|--endpoint)
        CHK_ENDPOINT="$2"
    shift
    ;;
    -t|--timeout)
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
            echo "ARG ERROR: Invalid timeout value '$2'!"
            usage && exit 3
        fi
        CHK_TIMEOUT="$2"
    shift
    ;;
    -r|--remove-after)
        CHK_REMOVE_ARTIFACT=true
    ;;
    *)
        echo -e "ARG ERROR: Unknown flag '`echo $flag | tr -d '-'`'!"
        usage && exit 3
esac
shift
done


# Validate required vars are declared, else error out
if [[ -z $CHK_PROXY ]]; then
    echo "ARG ERROR: Did not provide a proxy address!"
    usage && exit 3
elif [[ -z $CHK_ENDPOINT ]]; then
    echo "ARG ERROR: Did not provide a endpoint address!"
    usage && exit 3
fi

# Build the command
CHK_CMD="wget -e use_proxy=yes -e http_proxy="
addVarToCmd "${CHK_PROXY}:${CHK_PORT}"
addVarToCmd " ${CHK_ENDPOINT}"
if ! [[ -z $CHK_OUTPUT ]]; then
    addVarToCmd " -O ${CHK_OUTPUT}"
fi
if [[ "$CHK_REMOVE_ARTIFACT" = true ]]; then
    addVarToCmd " --delete-after"
fi

# Make the request, and exit with appropriate nagios status
eval timeout "${CHK_TIMEOUT}"s $CHK_CMD > /dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo "OK: successful exit status for proxy request"
    exit 0
else
    echo "ERROR: There was a non-zero exit status for the request"
    exit 2
fi
