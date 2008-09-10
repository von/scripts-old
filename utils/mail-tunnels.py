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
from threading import Thread, Event, RLock

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
    # Old, pre-May '06 value
    #ncsaWirelessLoginUrl = "https://ncsa-portal.wireless.ncsa.edu/captive_auth/"
    # New, post-May '06 value
    ncsaWirelessLoginUrl = "https://ncsa-portal.ncsa.uiuc.edu:8001"

######################################################################

if debug:
    print "Targets = %s" % targets

######################################################################
#
# Tunnel class
#

class Tunnel(Thread):
    ssh_program = "ssh"
    # Minimum time between connection attempts in seconds
    backoff = 60
    
    # State
    UNCONNECTED = 0
    CONNECTED = 1
    DYING = 2
    CONNECTING = 3

    state = UNCONNECTED
    pid = None

    # Are we in the process of quiting?
    quiting = False

    # Are we in the process of reconnecting?
    reconnecting = False

    debug = False

    def __init__(self, name, target,
		 auth="ssh-agent",
		 debug=False,
		 ping_target=None
		 ):
	"""name is nice name of target
	target is the hostname to pass to ssh"""
        Thread.__init__(self, name=name)
	self.name = name
	self.target = target
	self.auth = auth
	self.debug = debug
	self.ping_target = ping_target
	if auth == "ssh-agent":
	    self.check_creds = ssh_agent_check_creds
	    self.get_creds = ssh_agent_get_creds
	elif auth == "kerberos":
	    self.check_creds = kerberos_check_creds
	    self.get_creds = kerberos_get_creds
	elif auth == "none":
	    self.check_creds = none_check_creds
	    self.get_creds = none_get_creds
	else:
	    self.message("Unknown authentication method \"%s\"" % auth)
	    self.check_creds = none_check_creds
	    self.get_creds = none_get_creds
	self.pid = None
	self.last_attempt = None
	self.lock = RLock()
	self.event = Event()
	# Go ahead and set event so that run() will start first time
	# it is called.
	self.event.set()
	self.debugMsg("Tunnel to %s (%s) created." % (name, target))

    def run(self):
	self.debugMsg("Thread started.")
	while (not self.quiting):
	    self.event.wait(self.backoff)
	    self.event.clear()
	    self.acquireLock()
	    if self.state == self.CONNECTED:
		# Nothing to do
		pass
	    elif self.state == self.UNCONNECTED:
		if ((self.last_attempt == None) or
		    (time.time() - self.last_attempt > self.backoff)):
		    # Enough time elapsed since last attempt, try again
		    # to connect.
		    self.connect()
	    elif self.state == self.CONNECTING:
		# Nothing to do
		pass
	    elif self.state == self.DYING:
		# Nothing to do
		pass
	    else:
		# Unknown state
		self.message("Unknown state (%d)" % self.state)
		self.state = self.UNCONNECTED
	    self.releaseLock()

    def connect(self, force=False):
	"""Connect to server. If force is true, ignore wait period since last attempt."""
	self.debugMsg("connect() called (force = %d)" % force)
	if self.state != self.UNCONNECTED:
	    # Already connected (or in progress)
	    self.debugMsg("Attempt to connect tunnel but state is %d" %
			  self.state)
	    return self.pid
	# XXX force is not working here
	if not force:
	    if self.last_attempt != None:
		if time.time() - self.last_attempt < self.backoff:
		    # No enough time elapses since last attempt
		    # Try again later
		    self.debugMsg("Deferring connection - not enought time ellapsed since last attempt")
		    return None
	if self.ping_target != None:
	    # Do we have network connectivity?
	    if host_reachable(self.ping_target) == False:
		self.debugMsg("No network connectivity to %s" % self.target)
		return None
	self.acquireLock()
	self.state = self.CONNECTING
	# Make sure we have credentials to connect
        if self.check_creds() is False:
	    self.get_creds()
	self.debugMsg("Launching ssh")
	self.pid = os.spawnlp(os.P_NOWAIT,
			      self.ssh_program, self.ssh_program,
			      # No stdin
			      "-n",
			      # Do not run a program
			      "-N",
			      # No output messages
			      #"-q",
			      self.target)
	self.message("Connecting to %s" % self.target)
	self.last_attempt = time.time()
	self.state = self.CONNECTED
	self.releaseLock()
	return self.pid

    def forceConnect(self):
	return self.connect(force=True)

    def reconnect(self):
	if self.connected():
	    self.close(reconnect=True)
	else:
	    self.forceConnect()

    def connected(self):
	return (self.state == self.CONNECTED)

    def unconnected(self):
	return (self.state == self.UNCONNECTED)

    def sigchild(self, status):
	"""Called by signal handler when ssh process dies."""
	if self.state == self.UNCONNECTED:
	    self.message("Disconnected tunnel died.")
	    return
	self.acquireLock()
	# See if a signal killed the child
	if os.WIFSIGNALED(status):
	    # Yes, intentional death
	    self.message("Completed closing")
	else:
	    self.message("Died unexpectedly")
	self.exitStatus = status
	self.pid = None
	self.state = self.UNCONNECTED
	if self.reconnecting:
	    self.debugMsg("Reconnecting");
	    self.connect(force=True)
	    self.reconnecting = False
	self.releaseLock()

    def close(self, reconnect=False):
	self.acquireLock()
	if self.state == self.CONNECTED:
	    if reconnect:
		self.message("Reconnecting")
	    else:
		self.message("Disconnecting")
	    try:
		os.kill(self.pid, signal.SIGKILL)
	    except:
		self.message("Signal failed")
	    else:
		self.state = self.DYING
		# Allow for immediate reconnection after an explicit close
		self.last_attempt = None
		# Let SIGCHLD handler do the cleanup and call disconnected()
		self.reconnecting = reconnect
	self.releaseLock()

    def quit(self):
	self.acquireLock()
	self.quiting = True
	self.close()
	self.event.set()
	self.releaseLock()

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

    def acquireLock(self):
	self.lock.acquire()

    def releaseLock(self):
	self.lock.release()

    def message(self, msg):
	import time
	if self.pid:
	    pidStr = " (pid %d)" % self.pid
	else:
	    pidStr = ""
	timeStr = time.strftime("%H:%M")
	# Append '\r' here as otherwise some interaction with signals handling
	# and/or threads causes linefeed w/o carriage return.
	print "(%s) Tunnel to %s%s: %s\r" % (timeStr, self.name, pidStr, msg)

    def debugMsg(self, msg):
	if self.debug:
	    self.message(msg)

    def __del__(self):
	self.quit()

######################################################################
#
# SigChildHandler class
#
# Create a thread to handle a sigchild

class SigChildHandler(Thread):
    """Create a thread to handle a sigchild. We want this handling to
happen in a separate thread so that it blocks on the RLock for the
Tunnel opject."""
    
    def __init__(self, pid, status):
	Thread.__init__(self)
	self.pid = pid
	self.status = status
    
    def run(self):
	# Map pid to tunnel
	tunnel = None
	for tunnel in tunnels:
	    if tunnel.pid == self.pid:
		break
	if tunnel == None:
	    # No tunnel we know of, ignore
	    output("Caught unknown child (pid = %d)" % self.pid)
	    return
	tunnel.sigchild(self.status)

######################################################################
#
# NCSA Wireless portal login
#

class NCSAWirelessPortal:
    def __init__(self, url):
	self.url = url

    def login(self, username, passwd):
	import httplib
	import urllib
	params = urllib.urlencode({
		# These are the old values (pre-May '06)
		'login' : username,
		'passwd' : passwd,
		'go' : "Login",
		# These are the new values (post-May '06)
		'auth_user' : username,
		'auth_pass' : passwd,
		'redirurl' : "http://www.google.com/",
		'accept' : "Continue"
		})

	try:
	    response = urllib.urlopen(self.url, params)
	except IOError, e:
	    output("Could not connect to server (%s): %s" % (self.url, e))
	    return 0
    
	data = response.read()

	# Try and figure out if login failed by scraping html returned
	# We should have been redirected to google, so look for google
	if data.find("google") == -1:
	    output("Login failed.")
	    return 0
	output("Success.")
        # Go ahead and refresh our kerberos ticket
        #kerberos_get_creds(username, passwd)
        sys.stdout.flush()
	return 1

    def reachable(self):
        import urlparse
        parsedURL = urlparse.urlparse(self.url)
        return host_reachable(parsedURL.hostname)

######################################################################
#
# Utilitiy functions
#

def run_cmd(cmd, quiet=False):
    if quiet and not debug:
	cmd = cmd + " >& /dev/null"
    else:
	output("Running %s..." % cmd)
    # XXX Add timeout
    status = os.WEXITSTATUS(os.system(cmd))
    if not quiet:
	output("%s done." % cmd)
    if debug: output("Command returned %d" % status)
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
    password = getpass.getpass()
    return password


def host_reachable(target):
    """Return true if target is pingable."""
    status = run_cmd("ping -c 1 %s" % target, quiet=True)
    return (status == 0)

def output(msg):
    # Append '\r' here as otherwise some interaction with signals handling
    # and/or threads causes linefeed w/o carriage return.
    print "%s\r" % msg

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

def dispatch():
    """Run in a loop, getting user commands and dispatching them."""
    
    Getchar = Getch.Getch()

    # Main loop, runs forever
    while True:
	try:
	    if debug:
		output("Waiting for command.")
	    c = Getchar()
	    f = functions[c]
	except KeyError:
	    # Unknown key entered by user, ignore
	    if debug:
		output("Unknown key \"%s\"" % c)
	    pass
	except (IOError, termios.error):
	    # Interrupted system call, ignore
	    if debug:
		output("Interrupted system call.")
	    pass
	else:
	    # Call function bound to key
	    try:
		if debug:
		    output("Calling %s()" % f.__name__)
		f()
	    except SystemExit, e:
		raise e
	    except Exception, e:
		output("Caught exception: %s: %s" % (repr(e), e))
		raise e

def dump():
    """Dump the state of all tunnels."""
    for tunnel in tunnels:
	tunnel.dump()

def reconnect():
    """Reconnect all tunnels."""
    output("Reconnecting all tunnels...")
    for tunnel in tunnels:
	tunnel.reconnect()
    
def fetchmail(host=None):
    """Run fetchmail."""
    if runFetchmail is False:
	output("Fetchmail functionality disabled in configuration.")
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
    output("Pausing to allow tunnel setup...")
    sleep(reconnect_pause)
    fetchmail()

def ncsa_wireless_login(username = None, password = None):
    """Login to NCSA wirless portal"""
    portal = NCSAWirelessPortal(ncsaWirelessLoginUrl);
    if not portal.reachable():
        output("NCSA Wireless portal not reachable.")
        return False
    if username is None:
	username = getusername()
    output("Logging into NCSA wireless portal as %s" % username)
    if password is None:
	password = getpassword()
    portal.login(username, password)

def ps():
    cmd = "ps -auxwww | grep ssh"
    run_cmd(cmd)

def quit():
    """Quit."""
    output("Quiting...")
    # Manually close all of our tunnels, as garbage collection seems
    # to miss one (the last one?)
    for tunnel in tunnels:
	tunnel.quit()
    quitEvent.set()
    sys.exit(0)

def ncsa_login():
    """Logon to NCSA wireless portal and get Kerberos credential."""
    import getpass
    output("Using %s for username." % username)
    username = getpass.getuser()
    if password is None:
	password = getpass.getpass()
    ncsa_wireless_login(username, password)
 
def help():
    """Display help."""
    output("Help:")
    for key, func in functions.iteritems():
	output("[%s] %s" % (key, func.__doc__))

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
    if debug:
        output("handle_sigchild() called")
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

	# Fire off a thread to handle signal
	if debug: output("Caught sigchild for %d (status %d)" %
			 (pid, status))
	handler = SigChildHandler(pid, status)
	handler.start()
    if debug:
        output("handle_sigchild() done")

def handle_sigint(signum, frame):
    if debug:
        output("handle_sigint() called")
    quit()

def disable_signals():
    """Block signals for a critical piece of code."""
    if debug: output("Disabling signals.")
    for signum in range(1, signal.NSIG):
	try:
	    signal.signal(signum, signal.SIG_IGN)
	except:
	    # Some signals can't be set, ignore
	    continue

def enable_signals():
    """Enable signals."""
    if debug: output("Enabling signals")
    signal.signal(signal.SIGCHLD, handle_sigchild)
    signal.signal(signal.SIGINT, handle_sigint)

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
    try:
	ping_host = config.get(target, "pingHost")
    except:
	ping_host = None
    tunnel = Tunnel(target, host,
		    auth=auth,
		    debug=debug,
		    ping_target=ping_host)
    tunnels.append(tunnel)

for tunnel in tunnels:
    tunnel.start()

quitEvent = Event()

# Start dispatch thread to deal with user commands
dispatchThread=Thread(target=dispatch)
dispatchThread.start()

# Wait for some thread to say we're done
if debug: output("Main thread waiting for quit event.")
# Call in a loop with a one second timeout here so that we can do
# signal handling in between waits
while not quitEvent.isSet():
    quitEvent.wait(1.0)
if debug: output("Quit event detected.")
sys.exit(0)

# End code



	
    
