#!/bin/bash
CONFIG="config.ini"
PREFIX="CONFIGVAR"
source read_ini.sh
read_ini ${CONFIG} ${PREFIX}

# Print out variables that have been exported
ALL_VARS="${PREFIX}__ALL_VARS"
echo ${!ALL_VARS}

