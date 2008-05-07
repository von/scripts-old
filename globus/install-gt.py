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

defaultGlobusVersion="4.0.7"

######################################################################

import datetime
import optparse
import os
import os.path
import subprocess
import tempfile

######################################################################
#
# Configuration options to GT build

confOptions = [
    "--disable-rls"
    ]

######################################################################
#
# Utility functions

def errorExit(msg, exitValue=1):
    """Print error message and exit with exitValue."""

    stderr.write(msg)
    sys.exit(exitValue)

######################################################################

def main():
    # Parse our arguments
    usage = "usage: %prog [options] <Install Path>"
    parser = optparse.OptionParser(usage)ß
    parser.add_option("-v", "--globus-version", dest="globusVersion",
                      default=defaultGlobusVersion,
                      help="Specify version of Globus Toolkit to install (default is %default)")
    (options, args) = parser.parse_args()
    if len(args) != 1:
        parser.error("Missing path for installation")
    globusLocation = args.pop(0)

    # Check for required environment variables
    for var in ["JAVA_HOME", "ANT_HOME"]:
        if not os.environ.has_key(var):
            errorExit("Environment variable %s is not set" % var)

    # Make sure install paths exists and set GLOBUS_LOCATION
    if not os.path.exists(globusLocation):
        os.makedirs(globusLocation)
    os.environ['GLOBUS_LOCATION'] = globusLocation

    # Open our logfile and create a tee process to it
    logFilename = os.path.join(globusLocation, "install-gt.log")
    teePipe = subprocess.Popen(["tee", "-a", logFilename],
                               stdin = subprocess.PIPE)
    toTee = teePipe.stdin
    
    # Create functions for easy logging
    logMessage = lambda msg: toTee.write(msg.rstrip('\n') + "\n")
    logCmd = lambda args: subprocess.Popen(args,
                                           stdout=toTee,
                                           stderr=toTee).returncode

    def flaggedCmd(flagFile, args, description=None, exitOnError=True):
        """If flagFile does not exist, print description and execute args.

        If exitOnError is True, exits if command fails. Otherwise returns
        status. If flagFile exists, always returns zero."""
        if os.path.exists(flagFile):
            return 0
        if description:
            logMessage(description)
        status = logCmd(args)
        if status != 0:
            if exitOnError:
                errorExit("Command returned non-zero status.")
            else:
                return status
        # Touch the file, if the cmd didn't create it
        if not os.path.exists(flagFile):
            open(flagFile, 'w').close()
        return status

    # Create a temporary directory for working
    tmpDir = tempfile.mkdtemp()

    globusSourceDir="gt%s-all-source-installer" % globusVersion
    globusTarball="%s.tar.gz" % globusSourceDir

    # Full path to our unpacked source
    gtSourcePath = os.path.join(tmpDir, globusSourceDir)
    
    # Calculate our flag files
    gtInstalledFlag = os.path.join(globusLocation, "gt-installed")
    gtUnpackedFlag=os.path.join(globusSourcePath, "gt-unpacked")
    gtConfiguredFlag=os.path.join(globusSourcePath, "gt-configured")
    gtMadeFlag=os.path.join(globusSourcePath, "gt-made")

    # Are we already done?
    if os.path.exists(gtInstalledFlag):
        logMsg("Flag file %s exists. GT appears to be already installed"
               % gtInstalledFlag)
        sys.exit(0)

    # Figure out the URL to the Globus tarball
    (globusMajorVersion,
     globusMinorVersion,
     globusPointVersion) = globusVersion.split('.')
    # XXX Change this to http
    globusBaseURL="ftp://ftp.globus.org/pub"
    if (globusMajorVersion = "4") and (globusMinorVersion = "0"):
        # 4.0.x URLs are of the form "gt4/4.0/4.0.4/installers/etc/..."
        globusURL = "%s/gt%s/%s.%s/%s/installers/src/%s" % (globusBaseURL,
                                                            globusMajorVersion,
                                                            globusMajorVersion,
                                                            globusMinorVersion,
                                                            globusVersion,
                                                            globusTarball)
    elif (globusMajorVersion = "4") and (globusMinorVersion = "1"):
        # 4.1.x are of the form "gt4/4.1.1/installers/etc/..."
        globusURL = "%s/gt%s/%s/installers/src/%s" % (globusBaseURL,
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
    logMessage("GT Installation started")
    logMessage("Location: " + globusLocation)
    logMessage("LogFile: " + logFilename)
    logMessage("Date: " + datetime.datetime.now().strftime("%F %T"))
    logMessage("Version: " + options.globusVersion)
    logMessage("Temporary Directory: " + tmpDir)
    flaggedCmd("/tmp/flag",
               ["ls", "-l", globusLocation],
               "Doing ls")

    os.chdir(globusLocation)
    flaggedCmd(globusTarball,
               ["wget", "--progress=dot:mega", globusURL],
               "Getting Globus source tarball from %s" % globusURL)

    # Sanity check
    if not os.path.exists(globusTarball):
        errorExit("Failed to download tarball.")
    
    # Unpack into our temporary directory
    os.chdir(tmpDir)
    flaggedCmd(gtUnpackedFlag,
               ["tar", "xfz", os.path.join(globusLocation,
                                           globusTarball)],
               "Unpacking GT tarball...")

    # Configure globus
    os.chdir(gtSourcePath)
    confCmdArgs = ["configure", "--prefix=" + globusLocation]
    confCmdArgs.extend(confOptions)

    flaggedCmd(gtConfiguredFlag,
               confCmdArgs,
               "Configuring GT...")

    # And build
    flaggedCmd(gtMadeFlag,
               ["make"],
               "Building GT....")

    # And install
    flaggedCmd(gtInstalledFlag,
               ["make", "install"],
               "Installing GT...")

    # Clean up
    toTee.flush()
    toTee.close()
    teePipe.wait()

    logMessage("Success.")

if __name__ == "__main__":
    main()
