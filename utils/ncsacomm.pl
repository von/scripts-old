#!/usr/ncsa/bin/perl
######################################################################
#
# ncsacomm
#
# Utility to interactive with NCSA communications directory
#
# $Id$
#
######################################################################
#
# Defaults
#

# Database file
$DB = "/afs/ncsa/common/doc/web/people/comm.list.txt";

# Output mode
$OUTPUT_FUNC = \&OUTPUT_NORMAL;

######################################################################
#
# Parse command line arguments
#

use Getopt::Std;

getopts("p");

$OUTPUT_FUNC =  \&OUTPUT_PILOT
    if ($opt_p);

$REGEX = shift;

######################################################################
#
# Main Code
#

OPEN_DB();

while(@DATA = READ_DB_ENTRY($REGEX)) {
    &$OUTPUT_FUNC(@DATA);
}

CLOSE_DB();

exit 0;

#
# End Main Code
#
######################################################################
#
# Subroutines
#

######################################################################
#
# Open the database for reading. Uses global variable $DB.
#
# Arguments: None
# Returns: Nothing
# 

sub OPEN_DB() {
    if (!open(DB)) {
	print STDERR "Could not open \"$DB\": $!\n";
	exit 1;
    }
}


######################################################################
#
# Read the next entry from the DB. If $REGEX is defined then it
# returns the next entry matching $REGEX.
#
# Arguments: [$REGEX]
# Returns: Array of Name, Phone #, Email Addr, Room #, Building
#          or undefined if EOF encountered.
#

sub READ_DB_ENTRY() {
    my $REGEX = shift;

    my ($NAME, $PHONE, $EMAIL, $ROOM, $BUILDING, $BLANK_LINE);

    while(1) {
	$NAME = READ_DB_LINE();
	$PHONE = READ_DB_LINE();
	$EMAIL = READ_DB_LINE();
	$ROOM = READ_DB_LINE();
	$BUILDING = READ_DB_LINE();
	$BLANK_LINE = READ_DB_LINE();

	# Hack - check for tailer
	if ($ROOM =~ /NCSA COMMUNICATION DIRECTORY/) {
	    next;
	}

	if (!defined($REGEX) ||
	    !defined($NAME) ||
	    ($NAME =~ /$REGEX/i) ||
	    ($EMAIL =~ /$REGEX/i) ||
	    ($PHONE =~ /$REGEX/i)) {
		last;
	    }
    }

    return (defined($NAME) ? ($NAME, $PHONE, $EMAIL, $ROOM, $BUILDING) : ());
}

######################################################################
#
# Read a line from the DB and return line, doing any cleanup. Uses
# global variable DB.
#
# Arguments: None
# Returns: String
#

sub READ_DB_LINE() {
    my $LINE = <DB>;

    if (defined($LINE) && ($LINE =~ /\n$/)) {
	chop $LINE;
    }

    return $LINE;
}

######################################################################
#
# Close the database. Uses global variable DB.
#
# Arguments: None
# Returns: Nothing
#

sub CLOSE_DB() {
    close(DB);
}

######################################################################
#
# Output an entry in regular format.
#
# Arguments: Array of Name, Phone #, mail Addr, Room #, Building
# Returns: Nothing
#

sub OUTPUT_NORMAL {
    my ($NAME, $PHONE, $EMAIL, $ROOM, $BUILDING) = @_;

    printf("%-30s %10s %-20s %4s %-5s\n",
	   $NAME, $PHONE, $EMAIL, $ROOM, $BUILDING);
}

######################################################################
#
# Output an entry in CSV format for pilot.
#
# Pilot expects:
#  Last name, first name, title, company, work #, home #,
#  fax #, other, email, address, city, state, zip, country,
#  www (custom1), email2 (custom2),  (custom3), (custom4), note
#
# Arguments: Array of Name, Phone #, mail Addr, Room #, Building
# Returns: Nothing
#

sub OUTPUT_PILOT {
    my ($NAME, $PHONE, $EMAIL, $ROOM, $BUILDING) = @_;

    # $NAME is last, first already
    print $NAME . ",";
    # Title
    print ",";
    # Company
    print "NCSA,";
    # Work Phone #
    print $PHONE . ",";
    # Home Phone #
    print ",";
    # Fax #
    print ",";
    # Other #
    print ",";
    # Email
    print $EMAIL . ",";
    # Address
    print $ROOM . " " . $BUILDING . ",";
    # City
    print ",";
    # State
    print ",";
    # ZIP
    print ",";
    # Country
    print ",";
    # Custom1
    print ",";
    # Custom2
    print ",";
    # Custom3
    print ",";
    # Custom4
    print ",";
    # Note

    print "\n";
}
