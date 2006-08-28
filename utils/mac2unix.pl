#!/usr/bin/env perl
######################################################################
#
# mac2unix
#
# Convert a mac ascii file into a unix ascii file
#
# Kudos to: http://kb.iu.edu/data/agiz.html
#
# $Id$
#
######################################################################

while(<>) {
 
  # Convert CR to LF
  s/\r/\n/g;

  print;
}
