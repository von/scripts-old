#!/usr/bin/env python
######################################################################
#
# majordomo-approver
#
# $Id$
#

import os
import os.path
import sys
import string
import re

######################################################################

debug = False

######################################################################

class MajordomoConfig:

    configFileName = "~/.majordomo-approver/config"

    def __init__(self, listAddr):
        configFileName = os.path.expanduser(self.configFileName)
        try:
            os.stat(configFileName)
        except OSError, e:
            raise Exception("Could not read configuration file: %s" % e)
        import ConfigParser
        config = ConfigParser.SafeConfigParser()
        try:
            config.read(configFileName)
        except Exception, e:
            raise Exception("Error parsing configuration file: %s" % e)
        self.config = config
        self.listAddr = listAddr
        self.debug = debug

    def get(self, attribute, default=None):
        try:
            value = self.config.get(self.getMajordomoAddr(), attribute)
        except:
            # Fall through and try default section
            pass
        else:
            return value
        # Failed, try default section
        try:
            value = self.config.get("default", attribute)
        except:
            value = default
        return value

    def getListPassword(self):
        majordomoAddr = self.getMajordomoAddr()
        password = None
        try:
            password = self.config.get(self.getMajordomoAddr(),
                                       self.getListName())
        except:
            pass
        if password is None:
            try:
                password = self.config.get(self.getMajordomoAddr(), "default")
            except:
                pass
        return password

    def getMajordomoAddr(self):
        return "majordomo@" + self.getListDomain()

    def getListName(self):
        """Return the portion of the list address to the left of the '@' sign."""
        (listName, domainName) = self.listAddr.split("@")
        return listName

    def getListDomain(self):
        """Return the portion of the list address to the right of the '@' sign."""
        (listName, domainName) = self.listAddr.split("@")
        return domainName
        
    def getCCAddr(self):
        return self.get("cc")

    def getFromAddr(self):
        return self.get("from")

    def getSMTPServer(self):
        return self.get("smtpServer")

######################################################################

class MajordomoList:

    def __init__(self, listAddr):
        self.config = MajordomoConfig(listAddr)
        self.listAddr = listAddr
        self.cmds = []
        self.body = None
        self.debug = debug
        # Make sure we have a password for the list before proceeding
        self.password = self.config.getListPassword()
        if self.password is None:
            raise Exception("Unknown list \"%s\"", self.listAddr)

    def subscribe(self, addrs):
        self.processAddresses("subscribe", addrs)

    def unsubscribe(self, addrs):
        self.processAddresses("unsubscribe", addrs)

    def who(self):
        self.approve("who")

    def configure(self):
        # Uses different order
        cmd = "config %s %s" % (self.listAddr, self.password)
        self.addCmd(cmd)

    def newconfig(self, file):
        with open(file) as f:
            self.body = f.read()
            self.body = self.body + "\nEOF\n";
        cmd = "newconfig %s %s" % (self.listAddr, self.password)
        self.addCmd(cmd)

    def processAddresses(self, cmd, addrs):
        # Allow for a single value for addrs
        if not isinstance(addrs, list):
            addrs = [ addrs ]
        for addr in addrs:
            self.approve(cmd, addr)

    def approve(self, cmd, addr=None):
        cmd = "approve %s %s %s" % (self.password,
                                    cmd,
                                    self.listAddr)
        if addr is not None:
            cmd += " " + addr
        self.addCmd(cmd)

    def addCmd(self, cmd):
        self.cmds.append(cmd)

    def execute(self):
        import email
        cmdStr = ""
        for cmd in self.cmds:
            cmdStr += cmd + "\n"
        if self.body:
            cmdStr += self.body
        else:
            cmdStr += "\nend\n";
        msg = email.message_from_string(cmdStr)
        majordomoAddr = self.config.getMajordomoAddr()
        cc = self.config.getCCAddr()
        frm = self.config.getFromAddr()
        smtpServer = self.config.getSMTPServer()
        subject = "Majordomo commands to %s" % majordomoAddr
        msg['To'] = majordomoAddr
        msg['Subject'] = subject
        msg['Cc'] = cc
        msg['From'] = frm
        if debug:
            print "\nDEBUG MODE"
            print "\tSMTP Server: %s" % smtpServer
            print "Message:"
            print ""
            print msg.as_string()
        else:
            import smtplib
            smtpServer = smtplib.SMTP(smtpServer)
            smtpServer.sendmail(frm, [majordomoAddr, cc], msg.as_string())
            smtpServer.close()
        

######################################################################
#
# Read goofy Apple Mail format
#

def readAppleMailMsg(stream):
    msgs = []

    # As we read the lines, we going to translate from Mac to Unix
    table = string.maketrans("\r", "\n")

    # Convienence function to read line from stream
    # Also deletes all ascii 0x00 characters which Apple Mail seems
    # to put between each character
    getline = lambda s: s.readline().translate(table, "\x00")
    
    # Regex to match message deliminator
    delimRE = re.compile(r"^(-\*)+$")

    # Regex to match header fields
    headerRE = re.compile(r"(DATE|SENDER|SUBJECT|RECIPIENT): (.*)")

    # Regex to match a line with nothing but whitespace
    whitespaceRE = re.compile(r"^\s*$")

    # First, we read all the lines, handle translations and create an
    # array of properly formatted lines
    lines = []
    line = getline(stream)
    while len(line):
	lines.extend(line.split("\n"))
	line = getline(stream)

    # Find start of first message
    while len(lines):
	line = lines.pop(0)
	if delimRE.match(line):
	    break

    # Now iterate through lines parsing each message in turn
    while len(lines):
	msg = {}
	msgs.append(msg)

	# First skip any blank lines to get to headers
	while len(lines) and whitespaceRE.match(lines[0]):
	    lines.pop(0)

	# Parse headers
	while len(lines):
	    line = lines.pop(0)
	    match = headerRE.match(line)
	    if match:
		header = match.group(1)
		value = match.group(2)
		if header == "SENDER":
		    msg["from"] = value
		elif header == "RECIPIENT":
		    msg["to"] = value
		else:
		    msg[header.lower()] = value
	    else:
		break

	# Skip any blank lines
	while len(lines) and whitespaceRE.match(lines[0]):
	    lines.pop(0)

	# Rest is the body
	msg["body"] = ""
	while len(lines):
	    line = lines.pop(0)
	    if delimRE.match(line):
		break
	    msg["body"] += line.strip() + "\n"

    return msgs

######################################################################

def parseMajordomoRequest(msg):
    """Parse a majordomo request from a message body.

Returns a dictionary with the following keys:
  cmd - approve or confirm
  action - subscribe or unsubscribe
  list - list name
  addr - email address on which action is requested
  code - code for confirmation
"""
    request = {}
    body = msg["body"]

    # Whitespace seperator that includes escaped newlines
    # (use raw strings here to avoid python parsing backslashes)
    sep=r"[\s\\]+"

    # approve PASSWORD \
    # subscribe mithril \
    # address@ncsa.uiuc.edu
    approveRE = re.compile(r"approve PASSWORD" + sep +
			   "(subscribe|unsubscribe)" + sep +
			   # list name
			   "(\S+)" + sep +
			   # email address
			   "(.+)")

    match = approveRE.search(body)

    if match is not None:
	request["cmd"] = "approve"
	request["action"] = match.group(1)
	request["list"] = match.group(2)
	request["addr"] = match.group(3)
	return request

    # auth 1afc1ee9 subscribe security-announce "Von Welch" globus@vwelch.com
    confirmRE = re.compile(r"auth" + sep +
			   # Code
			   "(\S+)" + sep +
			   "(subscribe|unsubscribe)" + sep +
			   # listName
			   "(\S+)" + sep +
			   # name and address (not seperating at the moment)
			   "(.*)")

    match = confirmRE.search(body)
				
    if match is not None:
	request["cmd"] = "confirm"
	request["code"] = match.group(1)
	request["action"] = match.group(2)
	request["list"] = match.group(3)
	request["addr"] = match.group(4)
	return request

    # 550 5.1.1 /etc/mail/majordomo/ncsa.uiuc.edu/lists/cyberarch-wg: line 24: Kazi Anwar <kazi@ncsa.uiuc.edu>... User unknown
    bounceRE = re.compile(r"(\S+): line \d+:" + sep +
			   ".*<(\S+)>\.\.\. User unknown")

    match = bounceRE.search(body)

    if match is not None:
	request["cmd"] = "approve"
	request["action"] = "unsubscribe"
	request["list"] = match.group(1)
	request["addr"] = match.group(2)
	return request

    return None

######################################################################

def handleMsg(msg):
    """Handle a message encoded as a dictionary."""

    majordomoAddr = msg["from"].lower()

    request = parseMajordomoRequest(msg)
    if request is None:
	print "No request found in message from %s" % majordomoAddr
	return False

    result = False

    if request["cmd"] == "approve":
	# Look up list password by majodomo address and listname
	listPasswd = getListPassword(request["list"])
	if listPasswd is None:
	    print "Password for list %s at server %s not found." % (listName,
								    majordomoAddr)
	    return False

	print "Request to approve %s for %s on list %s from %s" % (request["addr"],
								   request["action"],
								   request["list"],
								   majordomoAddr)

	cmd = "approve %s %s %s %s" % (listPasswd,
				       request["action"],
				       request["list"],
				       request["addr"])

    elif request["cmd"] == "confirm":
	print "Request to confirm %s on list %s from %s" % (request["action"],
							    request["list"],
							    majordomoAddr)

	cmd = "auth %s %s %s %s" % (request["code"],
				    request["action"],
				    request["list"],
				    request["addr"])
    else:
	print "Unknown request type \"%s\"" % request["cmd"]
	return False

    result =  sendMajordomoCmd(majordomoAddr, cmd)

    if result:
	print "Command successfully send to %s" % majordomoAddr
    else:
	print "Failure processing request from %s" % majordomoAddr

    return result


######################################################################
#
# Command functions
#

def help():
    """Display help."""
    print """
Usage: %s <command> [<list-name> [<addresses>]]

Commands are:""" % myname
    for cmd in functionsWithNoArgs.keys():
        print "\t%s" % cmd
    for cmd in functionsWithListName.keys():
        print "\t%s <list name>" % cmd
    for cmd in functionsWithListAndAddresses.keys():
        print "\t%s <list name> <address> [<address>...]" % cmd

def parseEmail():
    """Parse email from stdin and approve requests."""
    inStream = sys.stdin

    msgs = readAppleMailMsg(inStream)

    print "Found %d messages." % len(msgs)

    for msg in msgs:
        result = handleMsg(msg)

######################################################################
#
# Utility functions
#

def popAndParseListName():
    """Pop listname from sys.argv and return MajordomoList object.

    Exits on any error, printing error to stdout."""
    import sys
    try:
        listAddr = sys.argv.pop(0)
    except:
        print "Usage: %s %s <list>" % (myname, cmd)
        sys.exit(1)
    
    try:
        list = MajordomoList(listAddr)
    except:
        print "Unknown list \"%s\"" % listAddr
        sys.exit(1)
    return list

######################################################################
#
# Main code
#

# Functions that take no arguments
# Value should be function to be called
functionsWithNoArgs = {
    "parse-email" : "parseEmail",
    "help" : "help",
}

# Functions with just a list name as a argument
# Value here is MajordomoList method() to invoke on list
functionsWithListName = {
    "who" : "who",
    "config" : "configure"
}

# Function with list name and set of addresses
# Value here is MajordomoList method() to invoke on list with addresses
# as arguments.
functionsWithListAndAddresses = {
    "subscribe" : "subscribe",
    "unsubscribe" : "unsubscribe",
}

# Functions with list name and filename
# Value here is MajordomoList method() to invoke with filename as argument.
functionsWithListAndFilename = {
    "newconfig" : "newconfig"
}

myname = sys.argv.pop(0)

try:
    cmd = sys.argv.pop(0)
except:
    help()
    sys.exit(1)

if functionsWithNoArgs.has_key(cmd):
    function = functionsWithNoArgs[cmd]
    eval("%s()" % function)
elif functionsWithListName.has_key(cmd):
    majordomoList = popAndParseListName()
    method = functionsWithListName[cmd]
    eval("majordomoList.%s()" % method)
    majordomoList.execute()
elif functionsWithListAndAddresses.has_key(cmd):
    majordomoList = popAndParseListName()
    method = functionsWithListAndAddresses[cmd]
    addresses = sys.argv
    eval("majordomoList.%s(%s)" % (method, addresses))
    majordomoList.execute()
elif functionsWithListAndFilename.has_key(cmd):
    majordomoList = popAndParseListName()
    method = functionsWithListAndFilename[cmd]
    filename = sys.argv.pop(0)
    eval("majordomoList.%s(\"%s\")" % (method, filename))
    majordomoList.execute()
else:
    print "Unknown command \"%s\". Use \"%s help\" for help." % (cmd, myname)
    sys.exit(1)

sys.exit(0)

