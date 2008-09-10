#!/usr/bin/python
######################################################################
#
# vm-do
#
# $Id$
#
######################################################################

# List of VMs I am responsible for
# From: http://mywiki.ncsa.uiuc.edu/wiki/VM_Servers
vms = []

# TODO: Put this into a configuration file
vms.append({ "hostname" : "csd-wiki.ncsa.uiuc.edu",
             "up": True,
             })
vms.append({ "hostname": "ncdir-wiki.ncsa.uiuc.edu",
             "up": True,
             })
vms.append({ "hostname": "buildbot.ncsa.uiuc.edu",
             "up": True,
             })
vms.append({ "hostname": "security.ncsa.uiuc.edu",
             "up": True,
             })
vms.append({ "hostname": "computer.ncsa.uiuc.edu",
             "up": True,
             })
# VMs that are currently down
vms.append({ "hostname": "gt-dev.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "spi-protected.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "spc.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "spi-unprotected.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "myvocs-box.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "gridshib-sp.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "gridshib-ca.ncsa.uiuc.edu",
             "up": False,
             })
vms.append({ "hostname": "osb3.ncsa.uiuc.edu",
             "up": False,
             })

# The SSH binary to use
sshCmd = "ssh"

######################################################################
import sys

#
# Parse our commandline options
from optparse import OptionParser
usage = "usage: %prog [options] [<command>]"
parser = OptionParser(usage=usage)
parser.add_option("-c", "--check",
                  action="store_true", dest="check",
                  help="Print VM name if command returns 0")
parser.add_option("-C", "--reverseCheck",
                  action="store_true", dest="reverseCheck",
                  help="Print VM name if command returns 1")
parser.add_option("-v", "--verbose",
                  action="store_true", dest="verbose",
                  help="Verbose mode")
(options, cmdArgs) = parser.parse_args()

if len(cmdArgs) == 0:
    parser.error("Missing <commands>")

if options.check and options.reverseCheck:
    parse.error("Cannot specify both '-c' and '-C'")

# Get names of all the VMs that should be up
vmList = map(lambda vm: vm["hostname"],
             filter(lambda vm: vm["up"] is True, vms))

# TODO: Check and make sure we have a SSH key in agent by running
# 'ssh-add -l' and checking for zero status.

import subprocess
for vm in vmList:
    sshArgs = [sshCmd, "-o", "BatchMode yes", vm]
    sshArgs.extend(cmdArgs)
    if options.verbose:
        print vm + ":"
    status = subprocess.call(sshArgs)
    if options.check:
        if status == 0:
            print vm
    elif options.reverseCheck:
        if status != 0:
            print vm
    else:
        if status != 0:
            print "Command failed on %s" % vm
            sys.exit(status)


