#!/bin/bash
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
openrc_location="openrc.sh" # Change this to the location of your downloaded OpenStack rc file

function usage {
    echo -e "${YELLOW}Usage: Optional args -r <OS_REGION_NAME> -s <server_name> -u <USERNAME> ${NC}"
}

function login {
    # Login with user from command line argument, else attempt automatic login by querying for the OS (e.g. centos or ubuntu), else ask user for login user
    server_n=$1
    user=$2

    # Query for server IP address to login to
    server_id=$(nova list | grep -i $server_n | awk '{ print $2 }')
    echo "server_id = $server_id"
    server_ip=$(nova show $server_id | grep network | awk '{ print $6 }')
    echo "server_ip = $server_ip"

    # If user was supplied as command line argument, login as this user
    if ! [ -z $user ] ; then
        ssh $user@$server_ip
        exit 0
    fi

    # Attempt OS detection to login as centos/ubuntu user automatically
    image_name=$(nova show $server_id | grep image | awk '{ print $5 }' | tr -d '()')
    image_desc=$(nova image-show $image_name | grep description)
    echo $image_desc | grep -qi 'centos'
    if [ $? -eq 0 ] ; then
        ssh centos@$server_ip
    else
        echo $image_desc | grep -qi 'ubuntu'
        if [ $? -eq 0 ];
            then ssh ubuntu@$server_ip
        else
            echo "Enter user you would like to login as:"
            read user
            ssh $user@$server_ip
        fi
    fi
}
function login_msg {
    echo -e "Logging in to ${GREEN}$1${NC}..."
}

# Source openrc file if user hasn't done this already
if [ -z "$OS_USERNAME" ] ; then
    source $openrc_location;
fi

# Handle command line arguments
REGION_SELECTED=false
SERVER_SELECTED=false
USER_ARG=""
while [[ $# > 1 ]]
do
flag="$1"
case $flag in
    -h|--help)
    usage && exit 1
    shift
    ;;
    -r|--region)
    OS_REGION_NAME="$2"
    echo -e "Read in ${YELLOW}$OS_REGION_NAME${NC} as ${GREEN}OS_REGION_NAME${NC}"
    REGION_SELECTED=true
    shift
    ;;
    -s|--server)
    server_name="$2"
    echo -e "Read in ${YELLOW}$server_name${NC} as ${GREEN}server_name${NC}"
    SERVER_SELECTED=true
    shift
    ;;
    -u|--user)
    USER_ARG="$2"
    echo -e "Read in ${YELLOW}$USER_ARG${NC} as ${GREEN}user${NC}"
    shift
    ;;
    *)
    # unknown option
    echo -e "${RED}Unknown flag `echo $flag | tr -d '-'`!${NC}" && usage
    exit 1
esac
shift
done

if [ "$REGION_SELECTED" = false ] ; then
    echo -e "Current region: ${YELLOW}$OS_REGION_NAME${NC}"
    echo "Type region name to switch to or press enter if OK:"
    read region_name
    if ! [ -z $region_name ] ;
        then export OS_REGION_NAME=$region_name
    fi
    echo -e "Using region ${YELLOW}$OS_REGION_NAME${NC}"
fi

if [ "$SERVER_SELECTED" = false ] ; then
    echo "Enter OpenStack server name to search for:"
    read server_name
    if [ -z $server_name ] ; then
        echo -e "${RED}Error: no server name specified${NC}" && usage
        exit 1
    fi
fi
server_list=($(nova list | awk '{if(NR>3)print $4}' | grep -i $server_name))
server_count=${#server_list[@]}
if [ "$server_count" -gt 1 ] ; then
    echo -e "Found ${YELLOW}$server_count${NC} matching servers..."
    count=1
    for server in ${server_list[@]};
        do echo -e "[${YELLOW}$count${NC}] $server"
        ((count++))
    done;
    echo "Which server would you like to login to? Enter number:"
    read server_number
    chosen_server=${server_list[$(($server_number -1))]}
    login_msg $chosen_server
    login $chosen_server $USER_ARG
elif [ "$server_count" -eq 1 ] ; then
    login_msg ${server_list[0]}
    login ${server_list[0]} $USER_ARG
else
    echo -e "${RED}No matching servers were found.${NC}"
    exit 1
fi
