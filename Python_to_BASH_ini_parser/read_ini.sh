#!/bin/bash
# Author Alastair Kerr
# Wrapper script - use python to interpret ini and produce output file
# Eval output file to grab variables interpreted from config 

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

function read_ini() 
{
    # Pass in filename of config as arg 1 and prefix to use as arg 2

    function check_prefix()
    {
        if ! [[ "${VARNAME_PREFIX}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] ;then
            echo -e "${RED}read_ini: invalid prefix '${VARNAME_PREFIX}'${NC}" >&2
            exit 1
        fi
    }

    function check_ini_file()
    {
        if [ ! -r "$1" ] ;then
            echo -e "${RED}read_ini: '${1}' doesn't exist or not readable${NC}" >&2
            exit 1
        fi
    }

    function validate_config_params() {
        CONFIG_FILE="$1"
        VARNAME_PREFIX="$2"

        check_ini_file "${CONFIG_FILE}"

        if [ -z "${VARNAME_PREFIX}" ]; then
            VARNAME_PREFIX="INI"
        else
            check_prefix
        fi
    }

    function read_config() {
        # Use python script to generate variable declarations, and eval these
        CONFIG_FILE="$1"
        VARNAME_PREFIX="$2"

        validate_config_params "${CONFIG_FILE}" "${VARNAME_PREFIX}"

        python vars_from_ini.py -i "${CONFIG_FILE}" -p "${VARNAME_PREFIX}" -o "${CONFIG_FILE}.vars"

        if [ ! $? -eq 0 ]; then
            echo -e "${RED}Failed to load config ${CONFIG_FILE}${NC}"
            exit 1
        fi

        while read -r line
        do
            eval "${line}"
        done < "${CONFIG_FILE}.vars"

        rm -f "${CONFIG_FILE}.vars"
    }

    CONFIG_FILE="$1"
    VARNAME_PREFIX="$2"
    read_config "${CONFIG_FILE}" "${VARNAME_PREFIX}"
}
