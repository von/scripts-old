#!/usr/bin/env python
######################################################################
#
# vm-do
#
# $Id$
#
######################################################################

import ConfigParser
import os.path
import sys

######################################################################

class VirtualMachine:

    def __init__(self, config, section):
        self.name = section
        self.hostname = self.name
        self._readOptions(config, section)

    def _readOptions(self, config, section):
        # Defaults
        self.options = {
            "up" : True,
            "os" : "unknown",
            "sshCmd" : "ssh",
            }
        for option in config.options(section):
            if not self.options.has_key(option):
                # Unknown option, ignore for now
                pass
            elif type(self.options[option]) is bool:
                self.options[option] = config.getboolean(section, option)
            elif type(self.options[option]) is int:
                self.options[option] = config.getint(section, option)
            else:
                self.options[option] = config.get(section, option)

    def getHostname(self):
        """Return FQDN of VM."""
        return self.hostname

    def getName(self):
        """Return nickname of VM."""
        return self.name

    def isUp(self):
        """Is the VM supposed to be up and running?"""
        return bool(self.options["up"])

    def __str__(self):
        return self.name()

    def runCmd(self, cmdArgs, input=None):
        """Execute command on VM, return return code."""
        import subprocess
        sshArgs = [self.options["sshCmd"],
                   "-o", "BatchMode yes",
                   self.getHostname()]
        sshArgs.extend(cmdArgs)
        pipe = subprocess.Popen(sshArgs,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                stdin=subprocess.PIPE)
        (stdout, stderr) = pipe.communicate(input)
        status = pipe.returncode
        return (status, stdout, stderr)

    def getOSVersion(self):
        """Return a string with the OS version on the machine."""
        # XXX FC-specific
        (status, stdout, stderr) = self.runCmd(["cat", "/etc/fedora-release"])
        return stdout

######################################################################

def checkSSHKeys():
    """Make sure we have a SSH key in our SSH agent."""
    import subprocess
    while True:
        # Run and squelch STDOUT
        pipe = subprocess.Popen(["ssh-add", "-l"],
                                stdout=subprocess.PIPE)
        pipe.communicate()  # Discard output
        status = pipe.returncode
        if status == 0:
            # We have a key
            break
        print "No SSH key detected in SSH-Agent."
        status = subprocess.call(["ssh-add"])
        
######################################################################

def runCmd(vms, options, args):
    if options.inputFilename:
        print "Taking input from file \"%s\"" % options.inputFilename
        inputFile = file(options.inputFilename)
        input = "".join(inputFile.readlines())
        inputFile.close()
    else:
        input = None
    for vm in vms:
        if not vm.isUp(): continue
        if options.printHostname:
            print vm.getName() + ": ",
            sys.stdout.flush()
        status = vm.runCmd(args, input=input)[0]
        print
        if status == 0:
            if options.check:
                print vm.getName()
        else:
            if options.reverseCheck:
                print vm.getName()
            elif options.exitOnError:
                print "Command failed on %s (status = %d)" % (vm.getName(),
                                                              status)
                sys.exit(status)

def getOS(vms, options, args):
    for vm in vms:
        if not vm.isUp(): continue
        print vm.getName() + ": " + vm.getOSVersion()


    
######################################################################

config = ConfigParser.ConfigParser()
config.read([os.path.expanduser('~/.vms/config')])

# Each section describes a virtual machine (except DEFAULT, which is not
# returned by sections())
sections = config.sections()
vms = []

for section in sections:
    vms.append(VirtualMachine(config, section))

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
parser.add_option("-e", "--exitOnError",
                  action="store_true", dest="exitOnError",
                  help="Exit on error to any VM.")
parser.add_option("-H", "--noHostname",
                  action="store_false", dest="printHostname", default=True,
                  help="Don't print hostname before command output.")
parser.add_option("-i", "--inputFilename", dest="inputFilename",
                  default=None,
                  help="read input from FILE", metavar="FILE")
parser.add_option("-O", "--printOSVersion",
                  action="store_true", dest="printOSVersion",
                  help="Print OS version on each VM.")
parser.add_option("-v", "--verbose",
                  action="store_true", dest="verbose",
                  help="Verbose mode")
(options, args) = parser.parse_args()

if len(args) == 0:
    parser.error("Missing command.")

command = args.pop(0)
cmds = {
    "run" : runCmd,
    "getOS" : getOS,
}

if not cmds.has_key(command):
    parser.error("Unknown command \"%s\"." % command)

checkSSHKeys()

f = cmds[command]
f(vms, options, args)

# Success
sys.exit(0)


