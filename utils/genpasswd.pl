#!/usr/bin/env perl
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

$char_type = "printable";

######################################################################

use Getopt::Std;

getopts("hl:p");

$char_type = "hex"
    if $opt_h;

$num_chars = $opt_l;

$char_type = "printable"
    if $opt_p;

######################################################################

srand();

my $num_chars = int(rand($MAXLENGTH - $MINLENGTH)) + $MINLENGTH
    if !defined($num_chars);

@printable = a..z;
push(@printable, A..Z);
push(@printable, 0..9);

for(my $char_num = 0; $char_num < $num_chars; $char_num++) {
    if ($char_type eq "printable") {
	my $index = int(rand($#printable + 1));
	print $printable[$index];
	
    } elsif ($char_type eq "hex") {
	my $char = sprintf("%x", int(rand(16)));
	print $char;

    } else {
	print STDERR "$0: Unknown type \"$char_type\".\n";
    }
}

print "\n";

