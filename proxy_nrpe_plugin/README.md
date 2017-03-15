# Proxy NRPE plugin

A pure-bash NRPE plugin designed for an E2E test of a proxy server. 

Customisable through command line-options to determine proxy server, port, endpoint used etc.

# Usage

Script's options are as follows:

```
Usage:
     -w <proxy address> - IP or resolveable FQDN
     -e <endpoint>      - Webpage or artifact to request
     [-p <port>]        - Port to connect to proxy on; default 3128
     [-o <output>]      - Filename to save output as; default use endpoint filename
     [-t <integer>]     - Request times out after this many seconds; default 10s
     [-r]               - Remove file after you download it
```

# Dependencies

Requires a modern version of BASH, must have wget installed. 

