#!/usr/local/bin/perl
######################################################################
#
# genpasswd
#
# Generate a random password.
#
# $Id$
#
######################################################################
#
# Defaults
#

$MINLENGTH = 8;

$MAXLENGTH = 12;

$PRINTABLE_MIN = 33;

$PRINTABLE_MAX = 126;

$CHAR_TYPE = "printable";

######################################################################

use Getopt::Std;

getopts("hl:p");

$CHAR_TYPE = "hex"
    if $opt_h;

$NUM_CHARS = $opt_l;

$CHAR_TYPE = "printable"
    if $opt_p;

######################################################################

srand();

$NUM_CHARS = int(rand($MAXLENGTH - $MINLENGTH)) + $MINLENGTH
    if !defined($NUM_CHARS);

for($CHAR_NUM = 0; $CHAR_NUM < $NUM_CHARS; $CHAR_NUM++) {
    if ($CHAR_TYPE eq "printable") {
	$ASCII = int(rand($PRINTABLE_MAX - $PRINTABLE_MIN)) + $PRINTABLE_MIN;
	print pack("c", $ASCII);
	
    } elsif ($CHAR_TYPE eq "hex") {
	$CHAR = sprintf("%x", int(rand(16)));
	print $CHAR;

    } else {
	print STDERR "$0: Unknown type \"$CHAR_TYPE\".";
    }
}

print "\n";

