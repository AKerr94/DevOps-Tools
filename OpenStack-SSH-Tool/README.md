# OpenStack-SSH-Tool
Simple script to search an OpenStack tenancy and SSH into a specified machine 

# Usage

You will need to download the openrc file for your tenancy from openstack and source it, or save it in the same directory as this folder with the name openrc.sh.

./ssh-tool.sh

This will run the script, which will prompt you for input for region and server name to search for, and attempt automatic login. Alternatively, these can be supplied as command line arguments with the following flags.

-r [region]

-s [server name]

-u [username]

# Dependencies

This tool uses the OpenStack nova client. This can be installed independently or comes as part of the OpenStack command-line clients. Refer to the official documentation for more information: http://docs.openstack.org/cli-reference/common/cli_install_openstack_command_line_clients.html
