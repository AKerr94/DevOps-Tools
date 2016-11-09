# validate_hosts_dns

Script for querying and checking validity of DNS records for a given set of hostnames. Checks that the forward A record and the reverse PTR record both exist and match for each hostname. 

```
Usage:
     [-h]    List this help
     [-s]    Specify single host to check
     [-i]    Input file with list of hosts to check
     [-o]    Output file name (if not specified, a temp file is used)
```

# Example commands

Check validity of a single server 

```
./ipa_validate_records.sh -s test01.example.come
```

Check validity of multiple servers listed in a file

```
./ipa_validate_records.sh -i hosts_list.txt
```
