#!/usr/bin/env perl
######################################################################
#
# unix2mac
#
# Convert a unix ascii file into a mac ascii file
#
# Kudos to: http://kb.iu.edu/data/agiz.html
#
# $Id$
#
######################################################################

while(<>) {

  # Convert LF to CR
  s/\n/\r/g;

  print;
}
