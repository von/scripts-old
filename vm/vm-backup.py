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
# TODO:
# Add file in VM dir with last backup time and checksum.
#
######################################################################

binaries = {
    "vmware-cmd" : "vmware-cmd",
    "tar" : "tar",
    "scp" : "scp",
    "md5sum" : "md5sum",
    "ls" : "ls"
}

######################################################################

import atexit
import fnmatch
import optparse
import os
import os.path
import re
import subprocess
import sys
import tempfile
import time

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
    """Run vmware-cmd with given arguments and return output as array of lines.

    If vmware-cmd returns non-zero, an Exception is thrown."""
    cmd = [binaries["vmware-cmd"]]
    cmd.extend(args)
    pipe = subprocess.Popen(cmd,
                            stdout=subprocess.PIPE,
                            # Try to keep stderr and stdout in sync
                            stderr=subprocess.STDOUT)
    status = pipe.wait()
    if status != 0:
        raise Exception("Execution of %s failed (returned %d)." % (cmd[0],
                                                                   status))
    # Remove newlines from lines as we read them
    output = [line.rstrip() for line in pipe.stdout.readlines()]
    return output

def runCmd(cmd):
    """Run command described by array and trturn outout as array of lines.

    If command returns non-zero an Exception is thrown."""

    status = subprocess.call(cmd,
                            # Try to keep stderr and stdout in sync
                             stderr=subprocess.STDOUT)
    if status != 0:
        raise Exception("Execution of %s failed (returned %d)." % (cmd[0],
                                                                   status))
    return status

def markTime():
    """Print timestamp."""
    print "Time is %s" % time.asctime()

######################################################################

# Use parser for usage and future expansion
usage="usage: %prog [options] <[user@]target hostname[:path]>"
parser = optparse.OptionParser(usage=usage)
parser.add_option("-d", "--destDir", dest="destDir", default=None,
                  help="save backups to DESTDIR", metavar="DESTDIR")
parser.add_option("-m", "--modDays", dest="modDays", type="int", default=None,
                  help="only backup VM if modified in last MODDAYS days.",
                  metavar="MODDAYS")
parser.add_option("-s", "--scpDest", dest="scpDest", default=None,
                  help="save backups to SCPTARGET. This be a scp-style destination (e.g. user@host:/some/path)", metavar="SCPTARGET")
(options, args) = parser.parse_args()

if not (options.destDir or options.scpDest):
    options.error("No destination specified. Need one of -d or -s.")

if options.destDir:
    workingDir = options.destDir
    if not os.path.exists(workingDir):
        os.makedirs(workingDir)
else:
    workingDir = tempfile.mkdtemp()
    atexit.register(os.rmdir, workingDir)
    print "Working directory is %s" % workingDir

# Get list of VM configuration files
VMconfigs = getListOfVMConfigs()

# List of tarfiles we created
tarfiles = []

for VMconfig in VMconfigs:
    print "Examining %s" % VMconfig
    markTime()
    dir = os.path.dirname(VMconfig)
    dirBase = os.path.basename(dir)
    parent = os.path.dirname(dir)
    filename = os.path.basename(VMconfig)
    tarfile = os.path.join(workingDir,
                           os.path.splitext(filename)[0] + ".tar.gz")
    if options.modDays:
        print "Checking to see if VM modified in last %d days." % options.modDays
        os.chdir(dir)
        # Get list of files modified after modDays ago
        modTime = time.time() - (options.modDays * 24 * 60 * 60)
        modList = [file for file in os.listdir(dir)
                   if os.path.getmtime(file) > modTime]
        # Ignore log files, as every vmware-cmd invocation gets logged.
        modList = [file for file in modList
                   if not fnmatch.fnmatch(file, "*.log")]
        if len(modList) == 0:
            print "VM files have not changed in %d days. Skipping." % options.modDays
            continue
        print "Modified files are: " + " ".join(modList)
    os.chdir(parent)
    state = getVMState(VMconfig)
    print "VM state is %s" % state
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
    print "Creating tarball %s:" % tarfile
    # If we just run tar with the directory name, tar will exit with
    # an error since we change the contents (access time) of the directory
    # contents while it is tar'ing the directory. So create a list of all
    # the files in the VM directory (with directory as prefix) and pass
    # that to tar.
    files = [os.path.join(dirBase, file) for file in os.listdir(dir)]
    status = runCmd([binaries["tar"],
                     "cfvz",
                     tarfile] + files)
    if status == 0:
        print "Tarball created."
        tarfiles.append(tarfile)
        runCmd([binaries["ls"], "-l", tarfile])
        runCmd([binaries["md5sum"], tarfile])
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

if options.scpDest and (len(tarfiles) > 0):
    print "Backing up tarfiles via scp to %s." % options.scpDest
    markTime()
    cmd = [binaries["scp"]]
    # Use blowfish for speed
    cmd.extend(["-c", "blowfish"])
    # Batch mode - no passwords or other prompts
    cmd.extend(["-B"])
    # Turn on verbose mode for debugging
    #cmd.extend(["-v"])
    cmd.extend(tarfiles)
    cmd.append(options.scpDest)
    status = runCmd(cmd)
    if status != 0:
        print "Error backing up tarfiles (scp returned %d)" % status
        sys.exit(1)

print "Done."
markTime()
sys.exit(0)

