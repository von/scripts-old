#!/usr/local/bin/perl -w
######################################################################
#
# rfc
#
# Get an rfc, keeping a cache on the local system.
#
# XXX Needs to handle non-numeric arguments better.
#
# $Id$
#
######################################################################


######################################################################
#
# Default configuration
#

$Configuration = {
		  # Where we cache rfcs
		  cache_dir                   => "/tmp",

		  # What format does the user want: html or txt
		  format                      => "txt",

		  # The lynx program
		  lynx                        => "lynx",

		  # Are we in debug mode?
		  debug                       => 1,
		 };

######################################################################
#
# Viewers for different formats
#

$Viewers = {
	    # Use OpenUrl() so we can specify new_window
	    html              => "netscape -noraise -remote \"OpenUrl(file:%s, new_window)\"",
	    txt               => "gnuclient -q %s",
	   };

######################################################################
#
# Parse commandline
#

use Getopt::Std;

my $arg = 0;

my %opts;

getopts('Df:', \%opts);

if (defined($opts{f})) {
  if (($opts{f} eq "txt") ||
      ($opts{f} eq "html")) {

    $Configuration->{format} = $opts{f};
  } else {
    print STDERR "Unrecognized format \"$opts{f}\"\n";
    $arg_error = 1;
  }
}

$Configuration->{debug} = 1 if $opts{D};

my $rfc = shift;

if (!defined($rfc)) {
  $arg_error = 1;
}

if ($arg_error) {
  print STDERR "
Usage: $0 [<options>] <RFC number>

Options are:
 -D                  Debug mode
 -f <format>         Specify format in which to view the RFC. Possible
                     formats are: txt, html
";
  exit(1);
}

######################################################################
#
# Main code
#

use File::Spec;

# Determine filename we are looking for handling special cases for index
my $base_filename;

if ($rfc eq "index") {
  $base_filename = "INDEX.rfc";

} else {
  # RFC #'s < 1000 have a leading 0
  $base_filename = sprintf("rfc%04d", $rfc);

}

# Name of the html source file in cache.
my $cache_filename = File::Spec->catfile($Configuration->{cache_dir},
					 $base_filename . ".html");

# Name of file in desired format
my $formatted_filename = File::Spec->catfile($Configuration->{cache_dir},
					     sprintf("%s.%s",
						     $base_filename,
						     $Configuration->{format}));

# See if the formatted file is in the cache
if ( ! -e $formatted_filename) {
  # Nope. See if the html version is? (This may be the same check.)
  if ( ! -e $cache_filename ) {
    # Nope, we'll just have to fetch it
    $Configuration->{debug} && print "No file in cache, fetching.\n";

    my $url = sprintf("http://www.cis.ohio-state.edu/htbin/rfc/%s.html",
		      $base_filename);

    system("lynx -source -dump $url > $cache_filename");

    if ((! -e $cache_filename ) || ( -z $cache_filename)) {
      print STDERR "Failed to retrieve RFC$rfc from web.\n";
      unlink($cache_filename);
      exit(1);
    }
  }

  # HTML version should now be in cache. Convert to requested format.
  if ($Configuration->{format} eq "txt") {
    $Configuration->{debug} && print "Converting html to txt format.\n";

    my $cmd = $Configuration->{lynx};
    $cmd .= " -dump $cache_filename";
    $cmd .= " > $formatted_filename";

    system($cmd);
  }

  if ( ! -e $formatted_filename ) {
    print STDERR "Failed to convert RFC $rfc to requested format.\n";
    exit(1);
  }
}

# Now launch viewer
my $viewer = $Viewers->{$Configuration->{format}};

$viewer =~ s/%s/$formatted_filename/g;

$Configuration->{debug} && print "Launching viewer: $viewer\n";

system($viewer);

exit(0);



