#!/usr/bin/env python
######################################################################
#
# vm-backup
#
# Backup all the VMs on the system to a remote directory via scp.
# Must have ability to scp to remote system without manual
# authentication.
#
# $Id$
#
######################################################################

binaries = {
    "vmware-cmd" : "vmware-cmd",
    "tar" : "tar",
    "scp" : "scp"
}

######################################################################

import atexit
import optparse
import os
import os.path
import re
import subprocess
import sys
import tempfile

######################################################################

def getListOfVMConfigs():
    return runVMWareCmd(["-l"])

def getVMState(conf):
    # First line of output should look like: getstate() = off
    output = runVMWareCmd([conf, "getstate"])[0]
    m = re.match("getstate\(\) = (\S+)", output)
    if not m:
        raise Exception("Could not parse state of VM (%s)" % output)
    return m.group(1)

def suspendVM(conf):
    runVMWareCmd([conf, "suspend"])

def startVM(conf):
    runVMWareCmd([conf, "start"])

def runVMWareCmd(args):
    """Run vmware-cmd with given arguments and return output as array of lines."""
    cmd = [binaries["vmware-cmd"]]
    cmd.extend(args)
    pipe = subprocess.Popen(cmd,
                            stdout=subprocess.PIPE)
    status = pipe.wait()
    if status != 0:
        raise Exception("vmware-cmd failed.")
    # Remove newlines from lines as we read them
    output = [line.rstrip() for line in pipe.stdout.readlines()]
    return output

######################################################################

# Use parser for usage and future expansion
usage="usage: %prog [options] <[user@]target hostname[:path]>"
parser = optparse.OptionParser(usage=usage)
(options, args) = parser.parse_args()

if len(args) != 1:
    parser.error("Missing target hostname.")
sshTarget = args.pop(0)

workingDir = tempfile.mkdtemp()
atexit.register(os.rmdir, workingDir)
print "Working directory is %s" % workingDir

# Get list of VM configuration files
VMconfigs = getListOfVMConfigs()

# List of tarfiles we created
tarfiles = []

for VMconfig in VMconfigs:
    print "Backing up %s" % VMconfig
    dir = os.path.dirname(VMconfig)
    dirBase = os.path.basename(dir)
    parent = os.path.dirname(dir)
    filename = os.path.basename(VMconfig)
    tarfile = os.path.join(workingDir,
                           os.path.splitext(filename)[0] + ".tar.gz")
    
    os.chdir(parent)

    state = getVMState(VMconfig)
    if state == "on":
        print "Suspending VM"
        try:
            suspendVM(VMconfig)
        except:
            print "Error suspending VM. Skipping."
            continue
        restartVM = True
    else:
        restartVM = False
    print "Creating tarball %s." % tarfile
    # If we just run tar with the directory name, tar will exit with
    # an error since we change the contents (access time) of the directory
    # contents while it is tar'ing the directory. So create a list of all
    # the files in the VM directory (with directory as prefix) and pass
    # that to tar.
    files = [os.path.join(dirBase, file) for file in os.listdir(dir)]
    status = subprocess.call([binaries["tar"],
                              "cfvz",
                              tarfile] + files)
    if status == 0:
        print "Tarball created."
        tarfiles.append(tarfile)
    else:
        print "Error creating tarfile."
    # Tar will sometimes return an error, but create the tarfile,
    # so just check if the tarball exists and register its deletion
    # if it does.
    if os.path.exists(tarfile):
        atexit.register(os.remove, tarfile)
    if restartVM:
        print "Restarting VM"
        try:
            startVM(VMconfig)
        except:
            print "Error restarting VM."
            continue

# Now copy tarballs to backup host
if len(tarfiles) == 0:
    print "No tarfiles to back up."
else:
    print "Backing up tarfiles to %s." % sshTarget
    cmd = [binaries["scp"]]
    cmd.extend(tarfiles)
    cmd.append(sshTarget)
    status = subprocess.call(cmd)
    if status != 0:
        print "Error backing up tarfiles (scp returned %d)" % status
        sys.exit(1)

print "Done."
sys.exit(0)

