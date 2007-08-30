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

import ConfigParser

configFileName = os.path.expanduser("~/.majordomo-approver/config")
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


def getMajordomoConfig(majordomoAddr, field):
    """Return the given configuration field for a majordomo address. Failing that return the default value. Failing that return None."""
    value = None
    try:
	value = config.get(majordomoAddr, field)
    except:
	pass

    if value is None:
	try:
	    value = config.get("default", field)
	except:
	    pass

    return value

def getFromAddr(majordomoAddr):
    """Return the from address to use for the command to the given
majordomo address."""
    return getMajordomoConfig(majordomoAddr, "from")

def getCCAddr(majordomoAddr):
    """Return the address to CC for the command to the given majordomo address.
Returns None if no CC to be performed."""
    return getMajordomoConfig(majordomoAddr, "cc")

######################################################################

def sendMajordomoCmd(majordomoAddr, cmd):
    """Send cmd to majordomo at given address."""
    import email
    import smtplib

    cmd += "\n"
    cmd += "end\n"
    msg = email.message_from_string(cmd)
    msg['To'] = majordomoAddr
    msg['Subject'] = "Majordomo commands to %s" % majordomoAddr
    cc = getCCAddr(majordomoAddr)
    msg['Cc'] = cc
    frm = getFromAddr(majordomoAddr)
    msg['From'] = frm

    if debug:
	print msg.as_string()
    else:
	# XXX Make SMTP host and portnumber configuration options
	smtpServer = smtplib.SMTP("localhost:11025")
	smtpServer.sendmail(frm, [majordomoAddr, cc], msg.as_string())
	smtpServer.close()

    return True

######################################################################

def getListPassword(listName):
    """Return the password for a list. Returns None on failure."""
    (list, domain) = listName.split("@")
    majordomoAddr = "majordomo@" + domain
    listPasswd = None
    try:
	listPasswd = config.get(majordomoAddr, listName)
    except:
	pass

    if listPasswd is None:
	try:
	    listPasswd = config.get(majordomoAddr, "default")
	except:
	    pass

    return listPasswd

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
# Main code
#

myname = sys.argv.pop(0)

try:
    cmd = sys.argv.pop(0)
except:
    cmd = "parseMsg"

if cmd == "parseMsg":
    inStream = sys.stdin

    msgs = readAppleMailMsg(inStream)

    print "Found %d messages." % len(msgs)

    for msg in msgs:
        result = handleMsg(msg)
elif cmd == "approve":
    try:
        action = sys.argv.pop(0)
        list = sys.argv.pop(0)
        addresses = sys.argv
    except:
        print "Usage: %s approve <action> <list> <address> [<address>...]" % myname
        sys.exit(1)
    passwd = getListPassword(list)
    if passwd is None:
        print "Unknown list \"%s\"" % list
    for address in addresses:
        cmd = "approve %s %s %s" % (active, list, address)


else:
    print "Unknown command \"%s\"." % cmd
    sys.exit(1)

sys.exit(0)

