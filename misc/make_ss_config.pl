#!/usr/local/bin/perl
######################################################################
#
# make_ss_config.pl
#
# Given a list of images, make a xml file suitable for use with
# make_slide_show.
#
# $Id$
#
######################################################################

use Getopt::Std;

# Defaults
getopts('t:', \%Options);

my $title = "SlideShow" || $Options{"t"};

######################################################################

printf("<slideshow title=\"%s\">\n", $title);

foreach $image (@ARGV)
{
  printf("  <slide image=\"%s\" title=\"Slide number \%n\"/>\n",
	 $image);
}

printf("</slideshow>\n");

exit(0);


