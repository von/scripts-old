#!/usr/bin/env python
"""vbox-add-vm

Add a virtual machine to VirtualBox's inventory (along with hard drive),
boot the VM, wait for it to power down and then remove it.

Intended for VMs on removable drives.

Note that the Virtual Box GUI apparently keeps either the xml or hard
drive file open even after they have been unregistered. This may cause
problems unmounting the drive until the VBox program is quite.

Todo:
* Check to see if VM or HDD is already register before doing so.
* Understand the VirtualBox SDK and Python interface well enough
  to use it:
  http://blogs.sun.com/nike/entry/python_api_to_the_virtualbox
"""

import atexit
import optparse
import os.path
import sys

#----------------------------------------------------------------------
#
# VirtualBox Management Functions
#

class VBoxError(Exception):
    def __init__(self, rc, msg):
        self.msg = msg
        self.rc = rc


def VBoxManage(*args):
    import subprocess
    cmdArgs = ["VBoxManage", "-q"]
    cmdArgs.extend(args)
    rc = subprocess.call(cmdArgs)
    if rc != 0:
        verboseMsg("VBoxManage returned %d" % rc)
        raise VBoxError(rc, None)
                
def registerVM(settingsFile):
    message("Registering VM %s" % settingsFile)
    VBoxManage("registervm", settingsFile)

def unregisterVM(settingsFile):
    message("Unregistering VM %s" % settingsFile)
    VBoxManage("unregistervm", settingsFile)

def registerHDD(hddFile):
    message("Registering HDD %s" % hddFile)
    VBoxManage("registerimage", "disk", hddFile)

def unregisterHDD(hddFile):
    message("Unregistering HDD %s" % hddFile)
    VBoxManage("unregisterimage", "disk", hddFile)

def mountHDD(hdd, vm, drive):
    """Add the given hdd to the vm. drive should be 'a', 'b', or 'd'"""
    message("Mounting HDD %s to VM %s as drive %s" % (hdd, vm, drive))
    VBoxManage("modifyvm", vm, "-hd%s" % drive, hdd)

def unmountHDD(vm, drive):
    "Drive should be 'a', 'b', or 'd'"""
    message("Unmounting drive %s from VM %s" % (drive, vm))
    VBoxManage("modifyvm", vm, "-hd%s" % drive, "none")

def startVM(vm):
    message("Starting VM")
    VBoxManage("startvm", vm)

def stopVM(vm):
    message("Stopping VM")
    VBoxManage("controlvm", vm, "poweroff")

def getVMInfo(vm):
    import subprocess
    output = subprocess.Popen(["VBoxManage", "-q", "showvminfo", vm],
                              stdout=subprocess.PIPE).communicate()[0]
    return output

def getVMState(vm):
    import re
    info = getVMInfo(vm)
    r = re.compile(r"State:\s*([\w ]+)\s*\(", re.MULTILINE)
    m = r.search(info)
    if m is None:
        verboseMsg("Unable to parse VM state.")
        return "Unknown"
    return m.group(1).strip()

def waitForVMShutdown(vm):
    import time
    message("Waiting for VM shutdown...")
    while 1:
        # Sleep first to give VM time to start
        time.sleep(5)
        state = getVMState(vm)
        if state == "powered off":
            message("VM shutdown detected.")
            break

#----------------------------------------------------------------------
#
# Output functions
#

# Default = 1, 0 = quiet, 2 = verbose
verbosityLevel = 1

def errorMsg(msg):
    sys.stderr.write(msg + "\n")

def message(msg):
    if verbosityLevel > 0:
        sys.stdout.write(msg + "\n")
        sys.stdout.flush()

def verboseMsg(msg):
    if verbosityLevel > 1:
        sys.stdout.write(msg + "\n")
        sys.stdout.flush()

#----------------------------------------------------------------------

def main(argv=None):
    global verbosityLevel

    if argv is None:
        argv = sys.argv
    usage = "usage: %prog [options] <vm settings file>"
    version= "%prog 1.0"
    parser = optparse.OptionParser(usage=usage, version=version)
    parser.add_option("-H", "--hdd", dest="hdd", action="append",
                      help="mount hdd from FILE", metavar="FILE")
    parser.add_option("-q", "--quiet", dest="verbosityLevel",
                      action="store_const", const=0,
                      help="surpress all messages")
    parser.add_option("-v", "--verbose", dest="verbosityLevel",
                      action="store_const", const=2,
                      help="be verbose")
    (options, args) = parser.parse_args()
    if len(args) != 1:
        parser.error("incorrect number of arguments")

    if options.verbosityLevel != None:
        verbosityLevel = options.verbosityLevel
        verboseMsg("Setting verbosity level to %d" % verbosityLevel)

    settingsFile = os.path.abspath(args.pop(0))
    if not os.path.exists(settingsFile):
        parser.error("settings file does not exist")
    vmName = os.path.splitext(os.path.basename(settingsFile))[0]

    try:
        registerVM(settingsFile)
    except VBoxError, err:
        errorMsg("Error registering VM %s" % settingsFile)
        return 1
    atexit.register(unregisterVM, vmName)

    driveIndex = 0
    driveLetters = ['a', 'b', 'd']
    if len(options.hdd) > len(driveLetters):
        errorMsg("Don't know how to handle more then %d HDDs" % len(driveLetters))
        return 1
    for hdd in options.hdd:
        hdd = os.path.abspath(hdd)
        try:
            registerHDD(hdd)
        except VBoxError, err:
            errorMsg("Error registering HDD %s" % hdd)
            return 1
        atexit.register(unregisterHDD, hdd)
        try:
            driveLetter = driveLetters[driveIndex]
            mountHDD(hdd, vmName, driveLetter)
        except VBoxError, err:
            errorMsg("Error mounting HDD %s as drive %s" % (hdd,
                                                            driveLetter))
            return 1
        atexit.register(unmountHDD, vmName, driveLetter)
        driveIndex += 1

    try:
        startVM(vmName)
    except VBoxError, err:
        errorMsg("Error starting VM %s" % vmName)
        return 1
    waitForVMShutdown(vmName)

    # atexit functions handle all the clean up

    return 0

if __name__ == "__main__":
    sys.exit(main())
