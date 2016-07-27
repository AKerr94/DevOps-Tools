#!/usr/bin/env python
"""
Author Alastair Kerr
This script reads in a given config and outputs an interpreted version,
which is easier to process line by line for the main bash script
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
    print "rewrite_config.py [-i <input>] [-o <output>]"
    print "Default input = config, default output = config_out" 

def readArgs(argv):
    """
    Read arguments from command line for config input/ output name 
    Defaults to config and config_out if not supplied
    """
    config_in = 'config'
    config_out = ''

    try:
        opts, args = getopt.getopt(argv,"hi:o:",["iconfig=","oconfig="])
    except getopt.GetoptError:
        logging.error("Failed to process command line arguments")
        printUsage()
        sys.exit(2)

    custom_out = False
    for opt, arg in opts:
        if opt == "-h":
            printUsage()
            sys.exit(0)
        elif opt in ("-i", "--iconfig"):
            logging.info("Using input config file '%s'" % arg)
            config_in = arg
        elif opt in ("-o", "--oconfig"):
            custom_out = True
            logging.info("Using output file '%s'" % arg)
            config_out = arg

    if not custom_out:
        config_out = "%s_out" % config_in

    return config_in, config_out

def interpretConfig(config_in):
    """
    Interpret config. Flattens/ expands config to array of rules 
    return ["source,destination,port" ...]
    """
    config_error = False
    try:
        with open(config_in) as f:
            lines = [line.rstrip('\n') for line in f]
            lines = filter(None, lines)
        
        config = []
        while(len(lines) > 0):
            # Process one line at a time, removing whitespace
            line = lines.pop(0).replace(' ', '')
            # Ignore comments
            if line[0] == '#':
                continue
            # Search for source node declaration
            elif line[0] == '[' and line[-1] == ']':
                source = line.lstrip('[').rstrip(']')
            # Other lines should be comma-separated destination,port(s) declarations
            else:
                line = filter(None, line.split(','))
                if not line:
                    logging.error("Invalid destination provided for a rule under stanza '%s'" % source)
                    continue
                destination = line.pop(0)
                # Catch invalid declarations, print error message and set error var 
                if len(line) == 0:
                    logging.error("No port provided for rule '%s' to '%s'" % (source, destination))
                    config_error = True
                    continue
                for port in line:
                    config.append("%s,%s,%s" % (source, destination, port)) 
    except:
        logging.error("Missing or invalid config '%s'" % config_in)
        sys.exit(1)

    # Exit if there were any errors
    if config_error:
        sys.exit(1)
    return config

def writeConfig(config, config_out):
    """
    Takes in interpreted config and writes to config_out
    Return 0 success or 1 error
    """
    try:
        with open(config_out, "w+") as f:
            for rule in config:
                f.write("%s\n" % rule)
    except Exception, e:
        logging.error(e)
        return 1
    return 0

def main(argv):
    """
    Main method
    Interpret user args, interpret config, rewrite in format for usage by bash script
    """
    logging.info("Processing command line options")
    config_in, config_out = readArgs(argv)

    logging.info("Interpreting config file '%s'" % config_in)
    config = interpretConfig(config_in)

    logging.info("Writing config now..")
    result = writeConfig(config, config_out)

    if result == 0:
        logging.info("Config written to '%s'" % config_out)
    else:
        logging.error("There was an error writing the config")
        sys.exit(1)

    logging.info("rewrite_config.py successfully executed")

if __name__ == "__main__":
    main(sys.argv[1:])
