#!/usr/local/bin/perl
######################################################################
#
# unix2dos
#
# Convert a unix ascii file into a dos ascii file
#
# $Id$
#
######################################################################

while(<>) {

  # Convert LF to CR-LF (only if not already done)
  s/([^\x0d])\x0a/$1\x0d\x0a/g;

  print;
}
