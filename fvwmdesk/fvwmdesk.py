#!/usr/local/bin/python
######################################################################

import os
import pickle
import sys
import string

######################################################################
#
# Setup
#

My_Name = sys.argv.pop(0)

Configuration = { 'config_file': os.environ["HOME"] + "/.fvwm/desks" }

######################################################################
#
# Desk list manipulation functions
#

def fvwmpager_labels(desks):
    desks = read_state_file()
    
    for desk in range(len(desks)):
        print "*FvwmPager: Label " + `desk` + " " + desks[desk]

######################################################################
#
# State file functions
#

def read_state_file():
    "Read the desks state file."

    path = Configuration["config_file"]
    
    if not os.path.exists(path):
        return []
    
    state_file = open(path, 'r')

    desks = state_file.readlines()

    # Strip whitespace including carriage returns
    for desk in range(len(desks)):
        desks[desk] = desks[desk].strip()
        
    state_file.close()

    return desks
        

def dump_state(desks):
    "Dump our desk state for debugging."

    print "Dump: " + str(len(desks)) + " enteries"
    for desk in range(len(desks)):
        print str(desk) + ": " + desks[desk]

######################################################################
##
## Main Code
    
desks = read_state_file()

dump_state(desks)

fvwmpager_labels(desks)

sys.exit(0)
