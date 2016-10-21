# FreeIPA_DNS

Script for querying, modifying or removing the explicit TTL value for all FreeIPA DNS Zones.

```
Usage:
     [-h]      List this help
     [-f]      Force: Skip user validation step
     [-m INT]  Max amount of zones LDAP search will return
     -i FILE   Pass file with list of zones to run on
     -a        Apply to all zones
     -s INT    Set all zones' TTL to <INT>
     -l        List all zones' TTLs
     -r        Remove explicit TTLs for all zones
```

# Example commands

List all zones and their TTL, do not ask for confirmation

```
./ipa_zones_ttl.sh -a -l -f
```

Set all zones from file 'my_zones' to 21600 seconds TTL. Asks for confirmation

```
./ipa_zones_ttl.sh -i my_zones -s 21600
```

Remove explicit TTL value from all zones (defaults to 24 hours). Asks for confirmation

```
./ipa_zones_ttl.sh -a -r
```

# Useful commands

You can get a sorted list of forward zones with this command:

```
ipa dnszone-find --sizelimit=500 | awk '/Zone\ name:\ [a-z]/ {print $3}' | sort
```

Increase `sizelimit` if you have more than 500 zones; this parameter is necessary as LDAPs default is to return 100 entries.

You can `grep` the result to only find certain zones. Output this to a file and pass this into the `ipa_zones_ttl.sh` script to apply a certain operation to this subset of zones.

e.g. find all zones with "searchstring" and then set their TTL to 600 seconds.

```
ipa dnszone-find --sizelimit=1000 | awk '/Zone\ name:\ [a-z]/ {print $3}' | grep "searchstring" | sort > /tmp/myzones

./ipa_zones_ttl.sh -f -i /tmp/myzones -s 600
```
