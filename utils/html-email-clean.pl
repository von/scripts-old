#!/usr/bin/env perl
######################################################################
#
# html-email-clean
#
# Finish cleaning up html email.
#
# $Id$
#
######################################################################

print "This message filtered with html-email-clean!\n";

while (<>)
{
    # Get rid of CR's
    s/0x0d//g;

    print;
}

exit 0

