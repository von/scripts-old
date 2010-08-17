#!/usr/bin/env python
"""network-fix

Check and fix, if needed, the wireless network interface on my Mac 
which keeps hanging.
"""
from optparse import OptionParser
import subprocess
import sys
import time

def getDefaultRoute():
    """Return our default route as a string."""
    args = ["netstat", "-rn"]
    output = subprocess.check_output(args)
    lines = output.splitlines()
    for line in output.splitlines():
        if line.startswith("default"):
            break
    else:
        # Didn't find default route
        return None
    # Expecting line to look like:
    # default            192.168.1.1        UGSc           35        0     en1
    fields = line.split()
    return fields[1]

def checkConnectivity(address, numberPings=3):
    """Check for connectivity to given address. Returns True or False."""
    args = ["ping", "-c", str(numberPings), address]
    result = subprocess.call(args)
    return (result == 0)

def main(argv=None):
    # Do argv default this way, as doing it in the functional
    # declaration sets it at compile time.
    if argv is None:
        argv = sys.argv
    parser = OptionParser(
        usage="%prog [<options>] <some arg>", # printed with -h/--help
        version="%prog 1.0" # automatically generates --version
        )
    parser.add_option("-q", "--quiet", action="store_true", dest="quiet",
                      help="run quietly", default=False)
    (options, args) = parser.parse_args()
    if options.quiet:
        print "Running quietly..."
    defaultRoute = getDefaultRoute()
    if defaultRoute:
        print "Default route is %s" % defaultRoute
        if checkConnectivity(defaultRoute):
            print "Default router is reachable."
            return(0)
        print "Cannot reach default router."
    else:
        print "Couldn't determine default route."
    # Bounce the interface
    interface="en1" # XXX This is an assumption
    print "Bouncing interface"
    subprocess.check_call(["sudo", "ifconfig", interface, "down"])
    subprocess.check_call(["sudo", "ifconfig", interface, "up"])

    # XXX Airport may not come back up here. Don't know how to detect that.
    # Looks like I can use the airport utility at
    # /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport /usr/sbin/airport
    # Kudos: http://osxdaily.com/2007/01/18/airport-the-little-known-command-line-wireless-utility/

    # Wait for default route to reappear
    defaultRoute = getDefaultRoute()
    maxTries = 10
    while defaultRoute is None:
        maxTries -= 1
        if maxTries == 0:
            print "Giving up waiting for interface to come back."
            return(1)
        print "Waiting for interface to come back..."
        time.sleep(2)
        defaultRoute = getDefaultRoute()
    print "Rechecking connectivity to default route."
    if not checkConnectivity(defaultRoute):
        print "Cannot reach the default router after interface bounce."
        return(1)
    print "Success."
    return(0)

if __name__ == "__main__":
    sys.exit(main())
