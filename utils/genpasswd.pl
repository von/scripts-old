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

my $min_length = 8;

my $max_length = 12;

my $output = "pasteBuffer";

my $char_type = "alphanumeric";

my %char_set = (
    alphanumeric       => [a..z, A..Z, 0..9],
    hex                => [0..9, A..F],
    );

######################################################################

use Getopt::Std;

getopts("c:hl:L:o");

if ($opt_h)
{
    print <<END;
Usage: $0 [<options>]

Options:
  -c <type>  Specify character set to generate password from (see below)
  -h         Print help and exit.
  -l <len>   Specify minimum password length (default: $min_length)
  -L <len>   Specify maximum password length (default: $max_length)
  -o         Output password to stdout.

Character set types (default is $char_type):
END

for my $key (keys(%char_set))
{
    print "\t$key\n";
}
exit(0);
}

$char_type = $opt_c
    if $opt_c;

$min_length = $opt_l
    if $opt_l;

$max_length = $opt_L
    if $opt_L;

$output = "stdout"
    if $opt_o;

######################################################################
#
# Check all our parameters

if (!defined($char_set{$char_type}))
{
    print STDERR "Unknown type \"$char_type\"\n";
    exit(1)
}

######################################################################
#
# Generate the password
#

srand();

my $num_chars = int(rand($max_length - $min_length)) + $min_length;

my $password = "";

my $chars = $char_set{$char_type};

for(my $char_num = 0; $char_num < $num_chars; $char_num++) {
    my $index = rand(@$chars);
    $password .= @$chars[$index];
}

#
# Output the password
#

if ($output eq "stdout")
{
    print $password . "\n";
}
elsif ($output eq "pasteBuffer")
{
    # XXX This is MAC OS X specific
    my $pid = open(HANDLE, "| pbcopy");
    if (!defined($pid))
    {
	print STDERR "Could not exec 'pbcopy': $!\n";
	exit(1);
    }
    print HANDLE $password;
    close(HANDLE);
    print "Password placed in paste buffer.\n"
}
else
{
    print STDERR "Unknwon output mode \"$output\"\n";
    exit(1);
}

exit(0);

### Local Variables: ***
### mode:perl ***
### End: ***
