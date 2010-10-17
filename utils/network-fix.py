#!/usr/bin/env python
"""network-fix

Check and fix, if needed, the wireless network interface on my Mac 
which keeps hanging.

Kudos to following for pointer to airport utility
http://osxdaily.com/2007/01/18/airport-the-little-known-command-line-wireless-utility/

"""
from optparse import OptionParser
import subprocess
import sys
import time

# Binaries
Binary = {
    # Not using the airport binary at the moment, but it provides for
    # lots of detail on airport configuration, so leaving it in case
    # that is ever useful.
    "airport" : "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport",
    "dscacheutil" : "dscacheutil",
    "networksetup" : "networksetup",
}

# Assumption this will always be the case
AIRPORT_INTERFACE = "en1"

def checkAndFixNetwork(interface="en1"):
    """Check wireless network and fix if needed.

    interface should be interface to check. 'en1' is assumed.

    Returns True if network was fixed, False otherwise."""
    fixed = False  # Return value
    if not checkAirport():
        print "Airport is off. Powering on..."
        fixed = True
        if not power_on_airport():
            raise Exception("Failed to power on airport")
        wait_for_default_route()
    defaultRoute = getDefaultRoute()
    if defaultRoute:
        print "Default route is %s" % defaultRoute
        if checkConnectivity(defaultRoute):
            print "Default router is reachable."
            return fixed
        print "Cannot reach default router."
    else:
        print "Couldn't determine default route."

    fixed = True
    print "Bouncing interface"
    subprocess.check_call(["sudo", "ifconfig", AIRPORT_INTERFACE, "down"])
    subprocess.check_call(["sudo", "ifconfig", AIRPORT_INTERFACE, "up"])

    # Airport may not come back up here.
    if not checkAirport():
        print "Airport is off. Powering on..."
        if not power_on_airport():
            raise Exception("Failed to power on airport.")

    # Flush DNS cache. Not sure why, but if we tried to access a site
    # while network was down, we get redirects to OpenDNS for a while
    # after network comes back up.
    flush_dns_cache()

    wait_for_default_route()

    print "Rechecking connectivity to default route."
    if not checkConnectivity(getDefaultRoute()):
        raise Exception(\
            "Cannot reach the default router after interface bounce.")

    print "Success."
    return fixed

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

def wait_for_default_route(maxTries=10):
    """Wait for default route to appear.

    Returns True on success.
    maxTries is number of second to wait before returning False.
    Called after interface bounced."""
    defaultRoute = getDefaultRoute()
    while defaultRoute is None:
        maxTries -= 1
        if maxTries == 0:
            print "Giving up waiting for interface to come back."
            return False
        print "Waiting for interface to come back..."
        time.sleep(2)
        defaultRoute = getDefaultRoute()
    return True

def checkConnectivity(address, numberPings=3):
    """Check for connectivity to given address. Returns True or False."""
    args = ["ping", "-c", str(numberPings), address]
    result = subprocess.call(args)
    return (result == 0)

def checkAirport():
    """Is the airport interface on and connected to a wifi network?"""
    args = [Binary["networksetup"], "-getairportpower", AIRPORT_INTERFACE]
    output = subprocess.check_output(args)
    lines = output.splitlines()
    # If Airport is off we'll get:
    # AirPort: Off
    if lines[0].endswith("Off"):
        return False
    elif lines[0].endswith("On"):
        return True
    # Punt
    raise Exception("Could not determine statust of airpot (%s)" % AIRPORT_INTERFACE)
    
def power_on_airport():
    """Power on the airport."""
    args = [Binary["networksetup"], "-setairportpower", AIRPORT_INTERFACE, "on"]
    result = subprocess.call(args)
    return (result == 0)

def flush_dns_cache():
    """Flush our DNS cache."""
    args = [Binary["dscacheutil"], "-flushcache"]
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
    parser.add_option("-c", "--continuous",
                      action="store_true", dest="continuous",
                      help="run continuously", default=False)
    parser.add_option("-d", "--delay",
                      action="store", type="int", dest="delay",
                      help="set delay for running continuously to DELAY",
                      metavar="DELAY", default=5)
    parser.add_option("-q", "--quiet", action="store_true", dest="quiet",
                      help="run quietly", default=False)
    (options, args) = parser.parse_args()
    if options.quiet:
        print "Running quietly..."
    if options.continuous:
        print "Runing continuously..."
        totalRuns = 0
        failures = 0
        while True:
            totalRuns += 1
            if checkAndFixNetwork():
                failures += 1
            print "Failure rate is %4.2f%% (%d/%d)" \
                % (failures * 100 / totalRuns, failures, totalRuns)
            time.sleep(options.delay)
    result = checkAndFixNetwork()
    if not result:
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
