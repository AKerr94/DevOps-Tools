# Python_to_BASH_ini_parser
Use superior processing speed of python to process an INI file, exporting the values as BASH variables 

# Credit

These scripts are based on work by https://github.com/rudimeier/bash_ini_parser

# Purpose

The purpose of these scripts is to imitate the functionality of rudimeiers pure BASH ini parser, but using python for the heavy processing in order to drastically increase efficiency when dealing with larger or more complex configuration files whose values must be used in BASH scripts. 

# Functionality

Python is used to handle the parsing of the configuration file, and generation of variable declarations to an output file. The BASH script performs eval operations on each declaration in order to allow for the variables to be used. 
