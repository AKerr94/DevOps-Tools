#!/usr/bin/env python
"""
Author Alastair Kerr

This script takes supplied ports, source and destination addresses,
interprets them and writes out a stanza format config file.
Using this script can make it easier to generate larger configs for multiple hosts

The output config can be used by the main firewalls checker script
"""

import sys
import getopt
import logging

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(levelname)s:%(message)s')
logging.addLevelName(logging.ERROR, "\033[1;31m%s\033[1;0m" % logging.getLevelName(logging.ERROR))
logging.addLevelName(logging.INFO, "\033[1;33m%s\033[1;0m" % logging.getLevelName(logging.INFO))

def printUsage():
    """
    Print usage message for running script
    """
    print "generator.py [-s <source addresses>] [-d <destination addresses>] [-p <ports>] [-o <output>]"
    print "You can supply either .config files or comma separated values (no whitespace), for each input parameter"
    print "Defaults: -s source.config -d dest.config -p ports.config -o output_config" 

def readArgs(argv):
    """
    Read arguments from command line for source, dest, ports 
    Parameters use default .config files if not specified
    """
    source_arg = "source.config"
    dest_arg = "dest.config"
    ports_arg = "ports.config"
    config_out = "output_config"

    try:
        opts, args = getopt.getopt(argv,"hs:d:p:o:",["source=","dest=","ports=","output="])
    except getopt.GetoptError:
        logging.error("Failed to process command line arguments")
        printUsage()
        sys.exit(2)

    for opt, arg in opts:
        if opt == "-h":
            printUsage()
            sys.exit(0)
        elif opt in ("-s", "--source"):
            logging.info("Using source arg: '%s'" % arg)
            source_arg = arg
        elif opt in ("-d", "--dest"):
            logging.info("Using dest arg: '%s'" % arg)
            dest_arg = arg
        elif opt in ("-p", "--ports"):
            logging.info("Using ports arg: '%s'" % arg)
            ports_arg = arg
        elif opt in ("-o", "--output"):
            logging.info("Using output location as: '%s'" % arg)
            config_out = arg

    return source_arg, dest_arg, ports_arg, config_out

def interpretArg(arg):
    """
    Interpret a .config or comma separated arg 
    Return list of values
    """
    if arg.split('.')[-1] == "config":
        with open(arg) as f:
            lines = [line.rstrip('\n') for line in f]
            lines = filter(None, lines)

        vals = []
        while len(lines) > 0:
            line = lines.pop(0)
            if line[0] == '#':
                continue
            if len(line.split(' ')) > 1 or len(line.split(',')) > 1:
                logging.error("Invalid config '%s': Please specify one value per line" % arg)
                sys.exit(1)
            vals.append(line)

        return vals

    else:
        return arg.split(',')

def processArgs(source_arg, dest_arg, ports_arg):
    """
    Process args to interpret lists of parameters 
    If a .config file was specified, read line by line
    Else interpret comma-separated values
    """
    source_list = interpretArg(source_arg)
    dest_list = interpretArg(dest_arg)
    ports_list = interpretArg(ports_arg)

    return source_list, dest_list, ports_list


def writeConfig(source_list, dest_list, ports_list, config_out):
    """
    Write stanza format config using interpreted values 
    """
    try:
        with open(config_out, 'w') as f:
            for source in source_list:
                f.write("[%s]\n" % source)
                for destination in dest_list:
                    ports = ""
                    for port in ports_list:
                        ports += ",%s" % port
                    line = "%s%s" % (destination, ports)
                    f.write("%s\n" % line)

    except Exception, e:
        logging.error("Error writing config to '%s': %s" % (config_out, e))
        sys.exit(1)

def main(argv):
    """
    Main method
    Interpret user args, read config values, write out config in stanza format
    """
    logging.info("Processing command line options")
    source_arg, dest_arg, ports_arg, config_out = readArgs(argv)
    source_list, dest_list, ports_list = processArgs(source_arg, dest_arg, ports_arg)

    logging.info("Writing output config to '%s'" % config_out)    
    writeConfig(source_list, dest_list, ports_list, config_out)

    logging.info("Successfully wrote config")


if __name__ == "__main__":
    main(sys.argv[1:])
