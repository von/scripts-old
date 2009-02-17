#!/usr/bin/env python
######################################################################
#
# install-gt
#
# Download and install globus to specified location.
#
# $Id$
#
######################################################################

import datetime
import optparse
import os
import os.path
import string
import subprocess
import sys
import tempfile

######################################################################
#
# Configuration options to GT build

confOptions = [
    "--disable-rls"
    ]

######################################################################
#
# Globals

# Handle to which we push normal output
outputHandle = None

######################################################################
#
# Utility functions

def errorExit(msg, exitValue=1):
    """Print error message and exit with exitValue."""
            
    sys.stderr.write(msg.rstrip('\n') + "\n")
    sys.exit(exitValue)

######################################################################

class OutputHandler:
    """Handle output for process."""

    def __init__(self, logFilename, appendLog = True):
        # Open our logfile and create a tee process to it
        teeCmdArgs = ["tee"]
        if appendLog:
            teeCmdArgs.append("-a")
        teeCmdArgs.append(logFilename)
        self.pipe = subprocess.Popen(teeCmdArgs, stdin = subprocess.PIPE)
        self.handle = self.pipe.stdin

    def message(self, msg):
        """Handle outputing a message."""

        self.handle.write(msg.strip('\n') + "\n")

    def logCmd(self, args):
        """Run command in args, logging output and returning returncode."""
        self.message("Executing command: " + " ".join(args))
        pipe = subprocess.Popen(args,
                                stdout=self.handle,
                                stderr=self.handle)
        status = pipe.wait()
        return status

    def flaggedCmd(self, flagFile, args,
                   description=None, exitOnError=True):
        """If flagFile does not exist, print description and execute args.
            
        If exitOnError is True, exits if command fails. Otherwise returns
        status. If flagFile exists, always returns zero."""
        if os.path.exists(flagFile):
            return 0
        if description:
            self.message(description)
        status = self.logCmd(args)
        if status is None:
            errorExit("Command returned status of None.")
        if status != 0:
            if exitOnError:
                errorExit("Command returned non-zero status (%d)." % status)
            else:
                return status
        # Touch the file, if the cmd didn't create it
        if not os.path.exists(flagFile):
            open(flagFile, 'w').close()
        return status

    def cleanup(self):
        self.handle.flush()
        self.handle.close()
        self.pipe.wait()

######################################################################

def main():
    # Parse our arguments
    usage = "usage: %prog [options] <GLOBUS_LOCATION>"
    parser = optparse.OptionParser(usage)
    parser.add_option("-a", "--appendLog",
                      action="store_true",
                      dest="appendLog",
                      help="Append to log file (instead of overwriting it) (default is %default)")
    parser.add_option("-C", "--clearPrevious",
                      action="store_true",
                      dest="clearPrevious",
                      help="Clear any previous build and install (defalt is %default)")
    parser.add_option("-l", "--logFilePath",
                      dest="logFilePath",
                      metavar="PATH",
                      help="Specify PATH for logfile (default is %default)")
    parser.add_option("-s", "--sourceCachePath",
                      dest="sourceCachePath",
                      metavar="PATH",
                      help="Specify PATH to cache GT tarballs (default is %default)")
    parser.add_option("-v", "--globus-version", dest="globusVersion",
                      metavar="VERSION",
                      help="Specify VERSION of Globus Toolkit to install (default is %default)")
    parser.set_defaults(appendLog = False,
                        clearPrevious = False,
                        globusVersion = "4.0.8",
                        logFilePath = "$GLOBUS_LOCATION/gt-install.log",
                        # XXX Multiple user problem
                        sourceCachePath = "/tmp")
    (options, args) = parser.parse_args()

    # Make sure install paths exists and set GLOBUS_LOCATION
    if len(args) != 1:
        parser.error("Missing path for installation")
    globusLocation = os.path.abspath(args.pop(0))
    if os.path.exists(globusLocation):
        if not os.path.isdir(globusLocation):
            errorExit("Globus Location is not a directory: %s" % globusLocation)
        if not os.access(globusLocation, os.W_OK):
            errorExit("Globus Location is not writable: %s" % globusLocation)
    else:
        os.makedirs(globusLocation)
    os.environ['GLOBUS_LOCATION'] = globusLocation

    # Now that GLOBUS_LOCATION is set, parse other values which
    # may depend on it
    globusVersion = options.globusVersion
    sourceCachePath = os.path.abspath(options.sourceCachePath)
    appendLog = options.appendLog
    clearPrevious = options.clearPrevious
    logFilePath = os.path.expandvars(options.logFilePath)

    # Check for required environment variables
    for var in ["JAVA_HOME", "ANT_HOME"]:
        if not os.environ.has_key(var):
            errorExit("Environment variable %s is not set" % var)
        path = os.environ[var]
        if not os.path.exists(path):
            errorExit("Environment variable %s points at non-existent path %s" %
                      (var, path))
        if not os.path.isdir(path):
            errorExit("Environment variable %s points at non-directory %s" %
                      (var, path))
        if not os.access(path, os.R_OK):
            errorExit("Environment variable %s points at non-readable path %s" %
                      (var, path))

    # Create a temporary directory for working
    tmpDir = os.path.join(tempfile.gettempdir(),
                          "install-gt-%d" % os.getuid())
    if not os.path.exists(tmpDir):
        os.makedirs(tmpDir, 0700)

    globusSourceDir="gt%s-all-source-installer" % globusVersion
    globusTarball="%s.tar.gz" % globusSourceDir

    # Full path to our unpacked source
    globusSourcePath = os.path.join(tmpDir, globusSourceDir)
    
    # Calculate our flag files
    gtInstalledFlag = os.path.join(globusLocation, "gt-installed")
    gtUnpackedFlag = os.path.join(globusSourcePath, "gt-unpacked")
    gtConfiguredFlag = os.path.join(globusSourcePath, "gt-configured")
    gtMadeFlag = os.path.join(globusSourcePath, "gt-made")

    # Are we clearing any previous state?
    if clearPrevious:
        print("Clearing previous state...")
        for file in [gtInstalledFlag,
                     gtUnpackedFlag,
                     gtConfiguredFlag,
                     gtMadeFlag]:
            if os.path.exists(file):
                os.remove(file)
        os.system("rm -rf " + os.path.join(tmpDir, "*"))
        os.system("rm -rf " + os.path.join(globusLocation, "*"))

    # Are we already done?
    if os.path.exists(gtInstalledFlag):
        errorExit("Flag file %s exists. GT appears to be already installed"
                  % gtInstalledFlag, exitValue=0)

    # OK, have at it...

    # Start up out output handler. Do this after clearing any previous
    # state, which could delete the log file created by the handler.
    output = OutputHandler(logFilePath, appendLog)
 
    # Figure out the URL to the Globus tarball
    (globusMajorVersion,
     globusMinorVersion,
     globusPointVersion) = map(int, globusVersion.split('.'))
    #globusBaseURL="ftp://ftp.globus.org/pub"
    globusBaseURL="http://www-unix.globus.org/ftppub"
    if (globusMajorVersion == 4) and (globusMinorVersion == 0):
        # 4.0.x URLs are of the form "gt4/4.0/4.0.4/installers/etc/..."
        globusURL = "%s/gt%d/%d.%d/%s/installers/src/%s" % (globusBaseURL,
                                                            globusMajorVersion,
                                                            globusMajorVersion,
                                                            globusMinorVersion,
                                                            globusVersion,
                                                            globusTarball)
    elif (globusMajorVersion == 4) and (globusMinorVersion >= 1):
        # 4.1.x and 4.2.x are of the form "gt4/4.1.1/installers/etc/..."
        globusURL = "%s/gt%d/%s/installers/src/%s" % (globusBaseURL,
                                                      globusMajorVersion,
                                                      globusVersion,
                                                      globusTarball)
    else:
        errorExit("Do not know how to compute url for GT version %s"
                  % globusVersion)

    #
    # OK. We're ready to start doing stuff.
    #

    # Start the log
    output.message("GT Installation started")
    output.message("Location: " + globusLocation)
    output.message("LogFile: " + logFilePath)
    output.message("Date: " + datetime.datetime.now().strftime("%F %T"))
    output.message("Version: " + options.globusVersion)
    output.message("Temporary Directory: " + tmpDir)
    output.flaggedCmd("/tmp/flag",
                      ["ls", "-l", globusLocation],
                      "Doing ls")

    # Download tarball
    os.chdir(sourceCachePath)
    output.flaggedCmd(globusTarball,
                      ["wget", "--progress=dot:mega", globusURL],
                      "Getting Globus source tarball from %s" % globusURL)

    # Sanity check
    if not os.path.exists(globusTarball):
        errorExit("Failed to download tarball.")
    
    # Unpack into our temporary directory
    os.chdir(tmpDir)
    output.flaggedCmd(gtUnpackedFlag,
                      ["tar", "xfz", os.path.join(sourceCachePath,
                                                  globusTarball)],
                      "Unpacking GT tarball...")

    # Configure globus
    os.chdir(globusSourcePath)
    confCmdArgs = ["./configure", "--prefix=" + globusLocation]
    confCmdArgs.extend(confOptions)

    output.flaggedCmd(gtConfiguredFlag,
                      confCmdArgs,
                      "Configuring GT...")

    # And build
    output.flaggedCmd(gtMadeFlag,
                      ["make"],
                      "Building GT....")

    # And install
    output.flaggedCmd(gtInstalledFlag,
                      ["make", "install"],
                      "Installing GT...")

    output.message("Creating administrative files...")
    startStopTemplate = string.Template("""#!/bin/sh
set -e
export GLOBUS_LOCATION=${GLOBUS_LOCATION}
export JAVA_HOME=${JAVA_HOME}
export ANT_HOME=${ANT_HOME}
export GLOBUS_OPTIONS="-Xms256M -Xmx512M"

. $$GLOBUS_LOCATION/etc/globus-user-env.sh

cd $$GLOBUS_LOCATION
case "$$1" in
    start)
        $$GLOBUS_LOCATION/sbin/globus-start-container-detached -p 8443
        ;;
    stop)
        $$GLOBUS_LOCATION/sbin/globus-stop-container-detached
        ;;
    *)
        echo "Usage: globus {start|stop}" >&2
        exit 1
       ;;
esac
exit 0
""")
    # All of the variables are environment variables, so just us the
    # environment as our mapping
    startStopString = startStopTemplate.substitute(os.environ)
    output.message("Creating $GLOBUS_LOCATION/start-stop")
    startStop = open(os.path.join(globusLocation, "start-stop"), "w")
    startStop.write(startStopString)
    startStop.close()

    initTemplate = string.Template("""#!/bin/sh -e
export GLOBUS_LOCATION=${GLOBUS_LOCATION}

case "$$1" in
  start)
    echo "Starting Globus container at $$GLOBUS_LOCATION"
    su - globus $$GLOBUS_LOCATION/start-stop start
    ;;
  stop)
    echo "Stopping Globus container at $$GLOBUS_LOCATION"
    su - globus $$GLOBUS_LOCATION/start-stop stop
    ;;
  restart)
    $$0 stop
    sleep 1
    $$0 start
    ;;
  *)
    printf "Usage: $$0 {start|stop|restart}\n" >&2
    exit 1
    ;;
esac
exit 0""")
    initString = initTemplate.substitute(os.environ)
    output.message("Creating $GLOBUS_LOCATION/init-globus")
    init = open(os.path.join(globusLocation, "init-globus"), "w")
    init.write(initString)
    init.close()

    output.message("Success.")

    output.cleanup()

    sys.exit(0)

if __name__ == "__main__":
    main()
