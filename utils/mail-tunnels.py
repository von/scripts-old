#!/usr/bin/env python
######################################################################
#
# mail-tunnels
#
# $Id$
#
import os
import os.path
import sys
import Getch
import signal
import termios
import time


######################################################################
#
# Configuration
#

import ConfigParser

configFileName = os.path.expanduser("~/.mail-tunnels/config")
try:
    os.stat(configFileName)
except OSError, e:
    print "Could not read configuration file: %s" % e
    sys.exit(1)

config = ConfigParser.SafeConfigParser()
try:
    config.read(configFileName)
except Exception, e:
    print "Error parsing configuration file: %s" % e
    sys.exit(1)

try:
    debug = config.getboolean("parameters", "debug")
    if debug: print "Debugging is on"
except:
    debug = False

try:
    target_string = config.get("parameters", "targets")
except Exception,e:
    print "Could not read target names from configuration file \"%s\": %s" % (configFileName, e)
    sys.exit(1)

targets = target_string.split(":")
if len(targets) == 0:
    print "No targets specified."
    sys.exit(1)

# Make sure configuration for all targets exists
for target in targets:
    if not config.has_section(target):
	print "Unknown target \"%s\"." % target
	sys.exit(1)

try:
    recheck_period = config.getint("parameters", "recheck_period")
except:
    recheck_period = 10

try:
    reconnect_pause = config.getint("parameters", "reconnect_pause")
except:
    reconnect_pause = 4

try:
    runFetchmail = config.getboolean("parameters", "run_fetchmail")
except:
    runFetchmail = True

try:
    ncsaWirelessLoginUrl = config.get("parameters", "ncsa_wireless_login_url")
except:
    ncsaWirelessLoginUrl = "https://ncsa-portal.wireless.ncsa.edu/captive_auth/"

######################################################################
#
# Tunnel class
#

class Tunnel:
    ssh_program = "ssh"
    # Minimum time between connection attempts in seconds
    backoff = 60
    
    # State
    UNCONNECTED = 0
    CONNECTED = 1
    DYING = 2
    CONNECTING = 3
    state = UNCONNECTED

    def __init__(self, name, target, auth="ssh-agent"):
	"""name is nice name of target
	target is the hostname to pass to ssh"""
	self.name = name
	self.target = target
	self.auth = auth
	if auth == "ssh-agent":
	    self.check_creds = ssh_agent_check_creds
	    self.get_creds = ssh_agent_get_creds
	elif auth == "kerberos":
	    self.check_creds = kerberos_check_creds
	    self.get_creds = kerberos_get_creds
	elif auth == "none":
	    self.check_creds = none_check_creds
	    self.get_creds = none_check_for_creds
	else:
	    print "Unknown authentication method \"%s\" for %s" % (auth, name)
	    self.check_creds = none_check_creds
	    self.get_creds = none_get_creds
	self.pid = None
	self.last_attempt = None

    def connect(self):
	if self.state != self.UNCONNECTED:
	    # Already connected (or in progress)
	    return self.pid
	if self.last_attempt != None:
	    if time.time() - self.last_attempt < self.backoff:
		# No enough time elapses since last attempt
		# Set alarm to try again later
		signal.alarm(self.backoff)
		return None
	self.state = self.CONNECTING
	# Make sure we have credentials to connect
        if self.check_creds() is False:
	    self.get_creds()
	self.pid = os.spawnlp(os.P_NOWAIT,
			      self.ssh_program, self.ssh_program,
			      # No stdin
			      "-n",
			      # Do not run a program
			      "-N",
			      # No output messages
			      #"-q",
			      self.target)
	print "Connecting to %s (%s, pid is %d)" % (self.name, self.target, self.pid)
	self.last_attempt = time.time()
	self.state = self.CONNECTED
	# This sleep prevents too many ssh's from starting at once
	# and getting deadlocked trying to lock the Kerberos cache
	sleep(1)
	return self.pid

    def regularCall(self):
	"""Called on regular based to allow tunnel to attempt conection or respond to events."""
	if self.state == self.CONNECTED:
	    # Nothing to do
	    pass
	elif self.state == self.UNCONNECTED:
	    if (self.last_attempt == None) or (time.time() - self.last_attempt > self.backoff):
		# Enough time elapses since last attempt, try again
		# to connect.
		self.connect()
	elif self.state == self.CONNECTING:
	    # Nothing to do
	    pass
	elif self.state == self.DYING:
	    if os.WIFSIGNALED(self.exitStatus):
		# Yes, intentional death
		print "Tunnel to %s completed closing (pid %d)" % (self.name, self.pid)
	    else:
		print "Tunnel to %s died unexpectedly (pid %d)" % (self.name, self.pid)
	    self.pid = None
	    self.state = self.UNCONNECTED
	else:
	    # Unknown state
	    pass

    def reconnect(self):
	self.close()
	self.connect()

    def sigchild(self, status):
	"""Called by signal handler when ssh process dies."""
	if self.state == self.UNCONNECTED:
	    # Shouldn't happen
	    print "Disconnected tunnel to %s died." % self.name
	# See if a signal killed the child
	elif os.WIFSIGNALED(status):
	    # Yes, intentional death
	    print "Tunnel to %s completed closing (pid %d)" % (self.name, self.pid)
	else:
	    print "Tunnel to %s died unexpectedly (pid %d)" % (self.name, self.pid)
	self.exitStatus = status
	self.pid = None
	self.state = self.UNCONNECTED

    def close(self):
	if self.state == self.CONNECTED:
	    print "Disconnecting from %s (pid %d)" % (self.name, self.pid)
	    try:
		os.kill(self.pid, signal.SIGKILL)
	    except:
		print "Signal to pid %d failed" % self.pid
		return
	self.state = self.DYING
	# Allow for immediate reconnection after an explicit close
	self.last_attempt = None
	# Let SIGCHLD handler to the cleanup and call disconnected()

    def dump(self):
	print "Tunnel to %s:" % self.name
	if self.state is self.UNCONNECTED:
	    print "\tUnconnected"
	elif self.state is self.DYING:
	    print "\tDying"
	elif self.state is self.CONNECTED:
	    print "\tConnected"
	elif self.state is self.CONNECTING:
	    print "\tConnecting"
	else:
	    print "\tUnknown state (%d)" % self.state
	if self.pid is not None:
	    print "\tPid is %d" % self.pid
	print "\tAuthentication: %s" % self.auth

    def __del__(self):
	self.close()

######################################################################
#
# NCSA Wireless portal login
#

def do_ncsa_wireless_login(url, username, passwd):

    import httplib
    import urllib

    print "Logging into NCSA wireless portal as %s" % username

    params = urllib.urlencode({'login' : username,
			       'passwd' : passwd,
			       'go' : "Login"})

    try:
	response = urllib.urlopen(url, params)
    except IOError, e:
	print "Could not connect to server (%s): %s" % (url, e)
	return 0
    
    data = response.read()

    # Try and figure out if login failed by scraping html returned
    index = data.find("There were errors processing your form.")
    if index != -1:
	# String found
	print "Login failed."
	return 0
    print "Success."
    return 1

######################################################################
#
# Utilitiy functions
#

def run_cmd(cmd, quiet=False):
    if quiet and not debug:
	cmd = cmd + " > /dev/null"
    else:
	print "Running %s..." % cmd
    # XXX Add timeout
    status = os.WEXITSTATUS(os.system(cmd))
    if not quiet:
	print "%s done." % cmd
    if debug: print "Command returned %d" % status
    return status

def sleep(seconds):
    # Need loop here because any signal interrupts the sleep() call
    sleep_start = time.time()
    while True:
	sleep_for = seconds - (time.time() - sleep_start)
	if sleep_for > 0:
	    time.sleep(sleep_for)
	else:
	    break

def getusername():
    import getpass
    return getpass.getuser()

def getpassword():
    import getpass
    # Turn off any signal handlers so that system call completes
    disable_signals()
    password = getpass.getpass()
    enable_signals()
    return password

def check_for_default_route():
    status = run_cmd("netstat -rn | grep default", quiet=True)
    return (status == 0)

######################################################################
#
# Credentials functions

def ssh_agent_check_creds():
    """See if the ssh agent has our keys loaded."""
    if run_cmd("ssh-add -l", quiet=True) != 0:
	return False
    return True

def ssh_agent_get_creds():
    """Add ssh key to ssh agent (run ssh-add)."""
    run_cmd("ssh-add")

def kerberos_check_creds():
    """See if we have a valid Kerberos ticket."""
    if run_cmd("klist -s", quiet=True) == 1:
	return False
    return True

def kerberos_get_creds(username = None, password = None):
    """Run kinit to get Kerberos ticket."""
    cmd = "kinit"
    if username:
	cmd += " " + username
    run_cmd(cmd)

def none_check_creds():
    return True

def none_get_creds():
    return True

######################################################################
#
# User commands
#

def dump():
    """Dump the state of all tunnels."""
    for tunnel in tunnels:
	tunnel.dump()

def reconnect():
    """Reconnect all tunnels."""
    print "Closing all tunnels..."
    for tunnel in tunnels:
	tunnel.close()
    print "Pausing to allow tunnel shutdown..."
    sleep(reconnect_pause)
    print "Reconnecting all tunnels..."
    for tunnel in tunnels:
	tunnel.connect()
    
def fetchmail(host=None):
    """Run fetchmail."""
    if runFetchmail is False:
	print "Fetchmail functionality disabled in configuration."
	return
    cmd = "fetchmail"
    # Get all mail
    cmd += " -a"
    if host is not None:
	cmd += " " + host
    run_cmd(cmd)

def reconnect_and_fetch():
    """Reconnect and run fetchmail."""
    reconnect()
    print "Pausing to allow tunnel setup..."
    sleep(reconnect_pause)
    fetchmail()

def ncsa_wireless_login(username = None, password = None):
    """Login to NCSA wirless portal"""
    if username is None:
	username = getusername()
    if password is None:
	password = getpassword()
    do_ncsa_wireless_login(ncsaWirelessLoginUrl, username, password)

def ps():
    cmd = "ps -auxwww | grep ssh"
    run_cmd(cmd)

def quit():
    """Quit."""
    print "Quiting..."
    # Manually close all of our tunnels, as garbage collection seems
    # to miss one (the last one?)
    for tunnel in tunnels:
	tunnel.close()
    sys.exit(0)

def ncsa_login():
    """Logon to NCSA wireless portal and get Kerberos credential."""
    import getpass
    print "Using %s for username." % username
    username = getpass.getuser()
    if password is None:
	password = getpass.getpass()
    ncsa_wireless_login(username, password)
    kerberos_get_creds(username, password)
 
def help():
    """Display help."""
    print "Help:"
    for key, func in functions.iteritems():
	print "[%s] %s" % (key, func.__doc__)

functions = {
    'D' : dump,
    'g' : fetchmail,
    'G' : reconnect_and_fetch,
    'h' : help,
    'n' : ncsa_wireless_login,
    'p' : ps,
    'q' : quit,
    'r' : reconnect,
}

######################################################################
#
# Signal handling
#

def handle_sigchild(signum, frame):
    while True:
	try:
	    (pid, status) = os.waitpid(-1, # any child
					os.WNOHANG)
	except OSError:
	    # No child waiting
	    pid = 0

	if pid == 0:
	    # No child waiting, we're done
	    break

	if debug: print "Caught sigchild for %d" % pid

	# Map pid to tunnel
	tunnel = None
	for tunnel in tunnels:
	    if tunnel.pid == pid:
		break
	if tunnel == None:
	    # No tunnel we know of, ignore
	    print "Caught unknown child (pid = %d)" % pid
	    continue
	tunnel.sigchild(status)

def handle_sigint(signum, frame):
    quit()

def handle_sigalarm(signum, frame):
    if check_for_default_route():
	# Connect any unconnected tunnels
	for tunnel in tunnels:
	    tunnel.connect()
    signal.alarm(recheck_period)

def disable_signals():
    """Block signals for a critical piece of code."""
    if debug: print "Disabling signals."
    for signum in range(1, signal.NSIG):
	try:
	    signal.signal(signum, signal.SIG_IGN)
	except:
	    # Some signals can't be set, ignore
	    continue

def enable_signals():
    """Enable signals."""
    if debug: print "Enabling signals"
    signal.signal(signal.SIGCHLD, handle_sigchild)
    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGALRM, handle_sigalarm)
    signal.alarm(recheck_period)

######################################################################
#
# Main code
#

enable_signals()

# Set up our tunnels
tunnels = list()
for target in targets:
    host = config.get(target, "host")
    auth = config.get(target, "auth")
    tunnel = Tunnel(target, host, auth=auth)
    tunnels.append(tunnel)

# And connect
for tunnel in tunnels:
    tunnel.connect()

Getchar = Getch.Getch()

# Main loop, runs forever
while True:
    try:
	c = Getchar()
	f = functions[c]
    except KeyError:
	# Unknown key entered by user, ignore
	pass
    except (IOError, termios.error):
	# Interrupted system call, ignore
	pass
    else:
	# Call function bound to key
	f()

# Should never get here



	
    
