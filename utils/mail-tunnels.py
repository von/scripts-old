#!/usr/bin/env python
######################################################################
#
# Configuration
#

targets = [
    "mallorn-mail-tunnel",
    "ncsa-mail-tunnel",
    "anl-mail-tunnel"
    ]

######################################################################

import os
import sys
import Getch
import signal
import termios
import time

######################################################################
#
# Tunnel class
#

class Tunnel:
    ssh_program = "ssh"

    def __init__(self, target):
	"""target is the hostname to pass to ssh"""
	self.target = target
	self.connect()

    def connect(self):
	print "Connecting to %s" % self.target
	self.pid = os.spawnlp(os.P_NOWAIT,
			      self.ssh_program, self.ssh_program,
			      # No stdin
			      "-n",
			      # Do not run a program
			      "-N",
			      self.target)
	return self.pid

    def reconnect(self):
	self.close()
	self.connect()

    def disconnected(self):
	"""Called by signal handler when ssh process dies."""
	self.pid = None

    def close(self):
	print "Disconnecting from %s (pid %d)" % (self.target, self.pid)
	try:
	    os.kill(self.pid, signal.SIGKILL)
	except:
	    pass
	self.disconnected()

    def __del__(self):
	self.close()

######################################################################
#
# SSH Agent Class
#

class SSHAgent:
    ssh_agent = "ssh-agent"
    ssh_add = "ssh-add"
    bind_address = "/tmp/ssh-agend-uid-%d" % os.geteuid()

    def __init__(self):
	self.start()
	
    def start(self):
	print "Starting SSH agent"
	self.pid = os.spawnlp(os.P_NOWAIT,
			      self.ssh_agent, self.ssh_agent,
			      # Specify bind address
			      "-a", self.bind_address,
			      # Debug mode == don't fork
			      "-d"
			      )
	os.environ['SSH_AUTH_SOCK'] = self.bind_address
	# We don't use this, just setting to be complete
	os.environ['SSH_AGENT_PID'] = str(self.pid)
	print "PID is %d" % self.pid
	self.add_keys()
	return self

    def disconnected(self):
	try:
	    del(os.environ['SSH_AUTH_SOCK'])
	    del(os.environ['SSH_AGENT_PID'])
	except:
	    pass
	self.pid = None

    def close(self):
	print "Killing SSH agent"
	try:
	    os.kill(self.pid, signal.SIGKILL)
	except:
	    pass
	self.disconnected()

    def __del__(self):
	self.close()

    def add_keys(self):
	print "Adding keys to SSH agent"
	while os.spawnl(os.P_WAIT, self.ssh_add, self.ssh_add) is 1:
	    # Try again
	    pass

    def remove_keys(self):
	print "Removing keys from SSH agent"
	os.spawnl(os.P_WAIT, self.add_add, self.ssh_add, "-D")

######################################################################
#
# User commands
#

def reconnect():
    print "Reconnecting all tunnels..."
    for tunnel in tunnels:
	tunnel.reconnect()

def fetchmail():
    print "Running fetchmail..."
    # Turn off any SIGCHILD handler so that system() call completes
    hndlr = signal.signal(signal.SIGCHLD, signal.SIG_DFL)
    os.system("fetchmail")
    print "Fetchmail done."
    # Restore previous SIGCHILD handler
    signal.signal(signal.SIGCHLD, hndlr)

def quit():
    sys.exit(0)

def help():
    print "Help:"
    for key, func in functions.iteritems():
	print "[%s] %s" % (key, func)

functions = {
    'g' : fetchmail,
    'h' : help,
    'q' : quit,
    'r' : reconnect
}

######################################################################
#
# Signal handling
#

def handle_sigchild(signum, frame):
    while True:
	(pid, status) = os.waitpid(-1, # any child
				    os.WNOHANG)
	if pid is 0:
	    # No child waiting, we're done
	    break

	#if agent.pid == pid:
	#    print "SSH Agent has died"
	#    agent.disconnected()
	#    return

	# Map pid to tunnel
	tunnel = None
	for tunnel in tunnels:
	    if tunnel.pid == pid:
		break
	if tunnel is None:
	    # No tunnel we know of, ignore
	    continue
	tunnel.disconnected()
	# See if a signal killed the child
	if os.WIFSIGNALED(status):
	    # Yes, intentional death, ignore
	    continue
	# Child self-terminated, restart
	# XXX We need a backoff here in case, e.g., network is down
	# XXX Maybe we can learn something from status?
	tunnel.connect()
    
def handle_sigint(sigint, frame):
    for tunnel in tunnels:
	tunnel.close()
    sys.exit(0)

######################################################################
#
# Main code
#

# Start up the SSH agent and add keys
#agent = SSHAgent()

# Set up our tunnels
tunnels = list()
for target in targets:
    tunnels.append(Tunnel(target))

# Set up signal handling
signal.signal(signal.SIGCHLD, handle_sigchild)
signal.signal(signal.SIGINT, handle_sigint)


getchar = Getch.Getch()

# Main loop, runs forever
while True:
    try:
	c = getchar()
	f = functions[c]
    except KeyError:
	# Unknown key entered by user, ignore
	pass
    except IOError:
	# Interrupted system call, ignore
	pass
    except termios.error:
	# Interrupted system call, ignore
	pass
    else:
	# Call function bound to key
	f()

# Should never get here



	
    
