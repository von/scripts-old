#!/usr/bin/env python
######################################################################
#
# Script to send bulk emails to a lot of folks from a template
# with substitution.
#
# Lots of work needed to generalize this needed.
#
# $Id$
#

import sys
import string
from optparse import OptionParser

######################################################################
#
# Email configuration
#
email_config = {}
email_config['server'] = "mail.ncsa.uiuc.edu"
email_config['from'] = "Von Welch <vwelch@ncsa.uiuc.edu>"
email_config['subject'] = "Research Programmer position at NCSA"

######################################################################
#
# This code snippet from
#   http://aspn.activestate.com/ASPN/Cookbook/Python/Recipe/305306
#

import re

def convert_template(template, opener='[', closer=']'):
    opener = re.escape(opener)
    closer = re.escape(closer)
    pattern = re.compile(opener + '([_A-Za-z][_A-Za-z0-9]*)' + closer)
    return re.sub(pattern, r'%(\1)s', template.replace('%','%%'))

#
# End snippet
#
######################################################################
#
# From http://www.employees.org/~donn/python/

import smtplib, string

FROMADDR = email_config['from']
SMTPSERVER = email_config['server']

def EmailOut(toaddrs, subj, text, cc=None):
   # SIMPLE FUNCTION THAT SENDS EMAIL.
   # toaddrs MUST be a python list of email addresses.

   # Convert list to string.
   s_toaddrs = string.join(toaddrs, ",")
   # Convert msg to smtp format.
   msg = ""
   msg += "To: %s\n" % s_toaddrs
   if cc is not None:
       msg += "Cc: %s\n" % string.join(cc, ",")
       toaddrs.append(cc)
   msg += "From: %s\n" % FROMADDR
   msg += "Subject: %s\n" % subj
   msg += """

%s
""" % text

   try:
      server = smtplib.SMTP(SMTPSERVER)
      server.sendmail(FROMADDR, toaddrs, msg)
      server.quit()
   except:
      raise

######################################################################

def choke(string):
    print "%s: %s" % (sys.argv[0], string)
    sys.exit(1)

usage = "usage: %prog [options] <template> <user list>"
parser = OptionParser(usage=usage)
parser.add_option("-c", "--cc", dest="cc", default=None,
		  help="carbon copy USER on all emails", metavar="USER")
(options, args) = parser.parse_args()
try:
    template_filename = args.pop(0)
    list_filename = args.pop(0)
except:
    raise
    choke("template filename and user list filename required")
try:
    print "Reading template file \"%s\"" % template_filename
    template_file = file(template_filename, "r")
    template = template_file.read()
    template_file.close()
except:
    print "Error reading template file \"%s\":" % template_filename
    raise
try:
    print "Reading list file \"%s\"" % list_filename
    list_file = file(list_filename, "r")
except:
    print "Error opening list file \"%s\":" % list_filename
    raise


linenumber = 0
while (True):
    line = list_file.readline()
    linenumber += 1
    if len(line) is 0:
	break
    vars = {}
    try:
	parts = string.split(line, ",")
	vars['name'] = string.strip(parts.pop(0))
	vars['department'] = string.strip(parts.pop(0))
	vars['email'] = string.strip(parts.pop(0))
    except:
	print "Malformed line %d of list" % linenumber
	continue

    try:
	text = convert_template(template) % vars
    except KeyError, e:
	print "Error applying line %s of list: %s undefined" % (linenumber, str(e))
	continue

    if options.cc is not None:
	cc = [options.cc]
    else:
	cc = None
    print "Sending email to %s (%s)" % (vars['name'], vars['email'])
    EmailOut([vars['email']], email_config['subject'], text, cc)




