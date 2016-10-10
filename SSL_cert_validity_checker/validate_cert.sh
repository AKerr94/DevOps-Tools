#!/bin/bash
# Author: Alastair Kerr
#
# Validates the certificate from a given host and port 
# Provide warning if cert is not yet active, or has already or will soon expire

LBE_SSL_TMP_FILE_PREFIX="/tmp/validate_cert"

function secondsToDays {
    # Remove any - sign and convert seconds (int) to days (2dp)
    seconds=$(echo $1 | sed 's/-//g')
    echo "scale=2; ${seconds} / 86400" | bc -l
}

function usage {
    echo -e "Usage (brackets indicate optional arg):\n" \
        "-s|--server    - server name e.g. lbe01.example.com\n" \
        "-p|--port      - port e.g. 443\n" \
        "[-h|--help]    - print this help message"
}


# Read in command line parameters
while  [[ $# > 0 ]]
do
flag="$1"
case $flag in
    -h|--help)
        usage; exit 0
        shift
        ;;
    -s|--server)
        HOST="$2"
        shift
        ;;
    -p|--port)
        PORT="$2"
        shift
        ;;
    *)
        echo -e "Unknown flag $(echo $flag | tr -d '-')"
        usage; exit 2
esac
shift
done

# Validate necessary variables are set 
if [ -z $LBE_SSL_TMP_FILE_PREFIX ]; then
    echo 'Config error: Null temp file prefix variable.' \
        'Please make sure $LBE_SSL_TMP_FILE_PREFIX is defined.'
    exit 2
elif [ -z $HOST ]; then
    echo -e "Usage error: No server name defined. Please pass a server name with -s\n"
    usage; exit 2
elif [ -z $PORT ]; then
    echo -e "Usage error: No port defined. Please pass a port with -p\n"
    usage; exit 2
fi

# Set unique temp file var for this host
LBE_SSL_TMP_FILE="${LBE_SSL_TMP_FILE_PREFIX}_${HOST}.tmp"

# Extract cert details from address
output=$(openssl s_client -connect "${HOST}:${PORT}" </dev/null 2>/dev/null \
    | openssl x509 -noout -subject -dates > ${LBE_SSL_TMP_FILE})

if [ $? -ne 0 ]; then
    echo "ERROR: Could not retrieve SSL certificate from ${HOST}:${PORT}"
    exit 2
fi

sed -E "s/^[^/]*= ?//g" "$LBE_SSL_TMP_FILE" > "${LBE_SSL_TMP_FILE}2"

# Extract individual dates for cert expiry 
before_date=$(sed -n '2p' "${LBE_SSL_TMP_FILE}2")
after_date=$(sed -n '3p' "${LBE_SSL_TMP_FILE}2")

# Validate variables are properly set and temp files exist before removing them
if [[ -f "${LBE_SSL_TMP_FILE}" ]] && [[ -f "${LBE_SSL_TMP_FILE}2" ]]; then
    if [[ $(dirname "${LBE_SSL_TMP_FILE}") = "/tmp" ]] && \
       [[ $(dirname "${LBE_SSL_TMP_FILE}2") = "/tmp" ]]; then
        rm -f "${LBE_SSL_TMP_FILE}" "${LBE_SSL_TMP_FILE}2"
    else
        echo "ERROR: Invalid temp file variable location - should be in /tmp"
        exit 2
    fi
else
    echo "ERROR: temp file does not appear to be a file"
    exit 2
fi

# Convert human readable dates to Unix time
before_date_epoch=$(date +%s -d "${before_date}")
after_date_epoch=$(date +%s -d "${after_date}")
current_epoch=$(date +%s)

# Check that cert is valid for current date 
before_check=$(($before_date_epoch - $current_epoch))

if [[ $before_check -gt 0 ]]; then
    echo "ERROR: Cert is not valid for another $(secondsToDays ${before_check}) days"
    exit 2
fi

after_check=$(($current_epoch - $after_date_epoch))

if [[ $after_check -gt 0 ]]; then
    echo "ERROR: Cert expired $(secondsToDays ${after_check}) days ago"
    exit 2
elif [[ $after_check -gt -172800 ]]; then
    echo "CRITICAL: Cert expires in the next 2 days:" \
        "$(secondsToDays ${after_check}) days remaining!"
    exit 2
elif [[ $after_check -gt -604800 ]]; then
    echo "WARNING: Cert expires in the next 7 days:" \
        "$(secondsToDays ${after_check}) days remaining!"
    exit 1
fi

echo "OK: Cert is valid for another $(secondsToDays ${after_check}) days"
exit 0

