#!/usr/bin/env python
"""
Author Alastair Kerr
This script parses a given ini file and prepares an output file,
which can be used to create environment variables in a bash script
"""

import sys
import getopt
import logging
import ConfigParser

logging.basicConfig(stream=sys.stdout, level=logging.ERROR, format='%(levelname)s:%(message)s')
logging.addLevelName(logging.ERROR, "\033[1;31m%s\033[1;0m" % logging.getLevelName(logging.ERROR))
logging.addLevelName(logging.INFO, "\033[1;33m%s\033[1;0m" % logging.getLevelName(logging.INFO))

def printUsage():
    """
    Print usage message for running script
    """
    print "rewrite_config.py -i <input> [-p <variable prefix>] [-o <output>]"
    print "Default prefix = INI, default output = <input>_out" 

def readArgs(argv):
    """
    Read arguments from command line for config input/ output name and variable prefix
    Default prefix = "INI", default output = "<input>_out"
    """
    config_in = ''
    config_out = ''
    prefix = 'INI'

    try:
        opts, args = getopt.getopt(argv,"hi:o:p:",["iconfig=","oconfig=","prefix="])
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
        elif opt in ("-p", "--prefix"):
            prefix = arg

    if not custom_out:
        config_out = "%s_out" % config_in

    return config_in, config_out, prefix

def configSectionMap(Config, section):
    """
    Create dictionary object for given section of the ini file
    """
    sectionDic = {}
    options = Config.options(section)

    for option in options:
        try:
            sectionDic[option] = Config.get(section, option).lstrip('"').rstrip('"')
            if sectionDic[option] == -1:
                logging.error("Skip: %s" % option)
                sectionDic[option] = None
        except Exception, e:
            logging.error("Exception on '%s'! %s" % (option, e))
            sys.exit(1)

    return sectionDic

def interpretConfig(config_in):
    """
    Interpret ini file, load into dictionary object
    """
    configDic = {}

    try:
        Config = ConfigParser.ConfigParser()
        Config.read("%s" % config_in)
        sections = Config.sections()

        for section in sections:
            configDic[section] = configSectionMap(Config, section)

    except:
        logging.error("Missing or invalid config '%s'" % config_in)
        sys.exit(1)

    return configDic

def generateVarDeclarations(configDic, prefix):
    """
    Takes in interpreted config dics
    Generates appropriate variable declarations 
    """
    declarations = []
    prefix = "%s__" % prefix

    # Add ALL_SECTIONS and NUMSECTIONS vars
    sections = ""
    numSections = 0
    for section in configDic.keys():
        sections = "%s %s" % (sections, section)
        numSections += 1
    declarations.append("%sALL_SECTIONS=\"%s\"" % (prefix, sections.lstrip()))
    declarations.append("%sNUMSECTIONS=\"%d\"" % (prefix, numSections))

    # Keep record of all section vars declared
    allVars = ""

    # For each parameter in each section, generate var name and associative value
    for section in configDic.keys():
        for param in configDic[section]:
            varName = "%s%s__%s" % (prefix, section, param)
            declarations.append("%s=\"%s\"" % (varName, configDic[section][param]))
            allVars = "%s %s" % (allVars, varName)

    declarations.append("%sALL_VARS=\"%s\"" % (prefix, allVars.lstrip()))

    return declarations

def writeVarDeclarations(declarations, config_out):
    """
    Takes in interpreted declarations from config and writes to config_out
    Return 0 success or 1 error
    """
    try:
        with open(config_out, "w+") as f:
            for declaration in declarations:
                f.write("%s\n" % declaration)
        return 0

    except Exception, e:
        logging.error(e)
        return 1

def main(argv):
    """
    Main method
    Interpret user args, interpret config, rewrite in format for usage by bash script
    """
    logging.info("Processing command line options")
    config_in, config_out, prefix = readArgs(argv)

    logging.info("Interpreting config file '%s'" % config_in)
    configDic = interpretConfig(config_in)

    logging.info("Generating variable declarations now..")
    declarations = generateVarDeclarations(configDic, prefix)

    logging.info("Writing config now..")
    result = writeVarDeclarations(declarations, config_out)

    if result == 0:
        logging.info("Config written to '%s'" % config_out)
    else:
        logging.error("There was an error writing the config")
        sys.exit(1)

    logging.info("vars_from_ini.py successfully executed")

if __name__ == "__main__":
    main(sys.argv[1:])
