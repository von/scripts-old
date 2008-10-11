#!/usr/bin/env python
"""
Backup all the VMs on the system to a remote directory via scp.
Must have ability to scp to remote system without manual
authentication.

Uses vmware-cmd:
http://www.vmware.com/support/esx21/doc/vmware-cmd.html

$Id$

TODO:
Add file in VM dir with last backup time and checksum.
"""
from __future__ import with_statement


######################################################################

binaries = {
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

class VirtualMachineException(Exception):
    pass

class VirtualMachineBaseObject:
    """Base object for VirtualMachine classes."""
    @staticmethod
    def _runVMWareCmd(args):
        """Run vmware-cmd with given arguments and return output as an array of strings.

        If vmware-cmd returns non-zero, a VirtualMachineException is thrown."""
        cmd = ["vmware-cmd"]
        cmd.extend(args)
        pipe = subprocess.Popen(cmd,
                                stdout=subprocess.PIPE,
                                # Try to keep stderr and stdout in sync
                                stderr=subprocess.STDOUT)
        # Remove newlines from lines as we read them
        output = [line.rstrip() for line in pipe.stdout.readlines()]
        status = pipe.wait()
        if status != 0:
            exceptionString = "Excution of %s failed (returned %d):\n%s"% (
                cmd[0],
                status,
                "\n".join(output))
            raise VirtualMachineException(exceptionString)
        return output

class VirtualMachineServer(VirtualMachineBaseObject):
    """Object representing a VM Server."""
    
    def getListOfVMs(self):
        return [VirtualMachine(f) for f in self._runVMWareCmd(["-l"])]

class VirtualMachine(VirtualMachineBaseObject):
    """Object representing a VM."""

    def __init__(self, configFile):
        self._configFile = configFile
        self._lastBackupFile = os.path.join(os.path.dirname(self._configFile),
                                            "vm-backup-last")
        self._name = os.path.splitext(os.path.basename(self._configFile))[0]

    def getState(self):
        """Return state of VM: on, off, suspended, stuck (requires user input) or unknown."""
        # First line of output should look like: getstate() = off
        output = self._runVMWareCmd([self._configFile, "getstate"])[0]
        m = re.match("getstate\(\) = (\S+)", output)
        if not m:
            raise VirtualMachineException("Could not parse state of VM (%s)" % output)
        return m.group(1)

    def suspend(self):
        """Suspend the virtual machine."""
        # "trysoft" tries a soft suspend first, and failing that does a
        # hard suspend. A soft suspend runs scripts inside the guest and
        # may fail if scripts are configured or vm-tools aren't running.
        self._runVMWareCmd([self._configFile, "suspend", "trysoft"])

    def start(self):
        """Start the virtual machine."""
        # See suspend() method for discussion of trysoft
        self._runVMWareCmd([self._configFile, "start", "trysoft"])

    def getLastBackupTime(self):
        """When was VM last backed up, in seconds since 1970.

        If VM has not back backed up, return None."""
        if not os.path.exists(self._lastBackupFile):
            return None
        return os.path.getmtime(self._lastBackupFile)

    def updateBackupTime(self):
        """Update the backup time to now."""
        with open(self._lastBackupFile, "w") as f:
            f.write("%d" % long(time.time()))

    def getModTime(self):
        """Get modification time of VM, in seconds since 1970."""
        dir = os.path.dirname(self._configFile)
        fileList = [os.path.join(dir, file) for file in os.listdir(dir)]
        # Ignore log files, as every vmware-cmd invocation gets logged.
        fileList = [file for file in fileList
                    if not fnmatch.fnmatch(file, "*.log")]
        # Ignore backup file itself
        fileList = [file for file in fileList
                    if not fnmatch.fnmatch(file, "vm-backup-last")]
        # Find the latest modtime and return it
        return max(map(os.path.getmtime, fileList))
    
        
    def backup(self, tarfile):
        """Back up VM to given tarball file."""
        restartVM = False
        state = self.getState()
        self.debug("VM state is %s" % state)
        if state == "on":
            self.debug("Suspending VM.")
            self.suspend()
            restartVM = True
        dir = os.path.dirname(self._configFile)
        # Path to parent directory of the VM directory
        parent = os.path.normpath(os.path.join(dir, ".."))
        # If we just run tar with the directory name, tar will exit with
        # an error since we change the contents (access time) of the directory
        # contents while it is tar'ing the directory. So create a list of all
        # the files in the VM directory (with vmDir as prefix) and pass
        # that to tar.
        files = [os.path.join(dir, file) for file in os.listdir(dir)]
        # I would like to makes files relative to parent, but no
        # obvious way to do that in python pre-2.6
        try:
            # Try to keep output from tar in sync with rest of output
            sys.stdout.flush()
            status = subprocess.call(
                ["tar", "cfvz", tarfile] + files,
                # We're going to create tarfile from parent of the VM
                cwd = parent,
                # Try to keep stderr and stdout in sync
                stderr=subprocess.STDOUT)
            sys.stdout.flush()
            if status != 0:
                raise VirtualMachineException("tar returned %d" % status)
        finally:
            if restartVM:
                self.debug("Restarting VM.")
                self.start()

    def configFile(self):
        """Return path to configuration file."""
        return self._configFile

    def name(self):
        """Return the VM name."""
        return self._name

    def __str__(self):
        return self.name()

    def debug(self, message):
        print message

######################################################################
#
# Utility functions

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
    print "Time is %s" % time.ctime()

######################################################################

def main(argv=None):
    if argv is None:
        argv = sys.argv
    # Use parser for usage and future expansion
    usage="usage: %prog [options]"
    parser = optparse.OptionParser(usage=usage)
    parser.add_option("-d", "--destDir", dest="destDir", default=None,
                      help="save backups to DESTDIR", metavar="DESTDIR")
    parser.add_option("-s", "--scpDest", dest="scpDest", default=None,
                      help="save backups to SCPTARGET. This be a scp-style destination (e.g. user@host:/some/path)", metavar="SCPTARGET")
    (options, args) = parser.parse_args(argv)

    if not (options.destDir or options.scpDest):
        parser.error("No destination specified. Need one of -d or -s.")

    if options.destDir:
        workingDir = options.destDir
        removeTarfiles = False
        if not os.path.exists(workingDir):
            print "Destination directory does not exist: %s" % options.destDir
            return 1
    else:
        workingDir = tempfile.mkdtemp()
        removeTarfiles = True
        atexit.register(os.rmdir, workingDir)
        print "Temporary directory is %s" % workingDir

    vmServer = VirtualMachineServer()
    vms = vmServer.getListOfVMs()

    # List of tarfiles we created
    tarfiles = []

    # List of VMs that successfully got tar'ed up
    tarredVMs = []
    
    for vm in vms:
        print "Examining \"%s\"" % vm.name()
        markTime()
        tarfile = os.path.join(workingDir, vm.name() + ".tar.gz")
        vmModTime = vm.getModTime()
        print "VM modification time: %s" % time.ctime(vmModTime)
        lastBackup = vm.getLastBackupTime()
        if lastBackup is None:
            print "VM has never been backed up."
        else:
            print "VM lastbackup: %s" % time.ctime(lastBackup)
            if vmModTime < lastBackup:
                print "VM has not changed since last backup."
                continue
        try:
            print "Backing up VM to %s" % tarfile
            vm.backup(tarfile)
        except Exception, e:
            print "Error backing up VM:\n" + str(e)
            if os.path.exists(tarfile):
                os.remove(tarfile)
            continue
        print "Tarball created."
        tarfiles.append(tarfile)
        tarredVMs.append(vm)
        runCmd([binaries["ls"], "-l", tarfile])
        # This takes a while...
        # runCmd([binaries["md5sum"], tarfile])
        if os.path.exists(tarfile) and removeTarfiles:
            atexit.register(os.remove, tarfile)

        if options.scpDest and (len(tarfiles) > 0):
            print "Backing up tarfiles via scp to %s." % options.scpDest
            markTime()
            cmd = [binaries["scp"]]
            # Use blowfish for speed
            cmd.extend(["-c", "blowfish"])
            # Batch mode - no passwords or other prompts
            cmd.extend(["-B"])
            # Turn on verbose mode for debugging
            # cmd.extend(["-v"])
            # Names of tarfiles
            cmd.extend(tarfiles)
            cmd.append(options.scpDest)
            status = runCmd(cmd)
            if status != 0:
                print "Error backing up tarfiles (scp returned %d)" % status
                return 1

    markTime()

    # Success, mark VMs as backed up
    for vm in tarredVMs:
        print "Marking %s as backed up." % vm.name()
        vm.updateBackupTime()

    print "Done."
    return 0

if __name__ == "__main__":
    sys.exit(main())
