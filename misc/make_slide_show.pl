#!/usr/local/bin/perl
######################################################################
#
# make_slide_show
#
# Given the name of a bunch of image files on the command line
# build html files around them.
#
# $Id$
#
######################################################################

use XML::Simple;

######################################################################

######################################################################
#
# Parse command line arguments
#

my $config_filename = shift ||
  usage_exit("Missing configuration filename");

######################################################################
#
# Parse configuration file
#

my $Config = XMLin($config_filename);

######################################################################
#
# Set up state
#

my %State;

$State{toc_filename} = $Config->{'toc_filename'} || "index.html";
$State{title} = $Config->{'title'} || "Slide Show";

if (ref($Config->{slide}) eq "ARRAY") {
  $State{photos} = $Config->{slide};
} else {
  # Single slide, need to convert to an array
  $State{photos} = [ $Config->{slide} ];
}

$State{filename_template} = "slide%04d.html";

######################################################################
#
# Main loop
#

my $number_of_photos = $#{$State{photos}} + 1;

open(TOC, ">$State{toc_filename}") ||
  die "Could not open $State{toc_filename} for writing: $!";

  print TOC "
<html>
<head>
<title>$State{title}</title>
</head>
<body>
<h1>$State{title}</h1>
<ol>
";

for(my $photo_number = 1;
    $photo_number <= $number_of_photos;
    $photo_number++) {

  my $photo = $State{photos}[$photo_number - 1];
  my $title = $photo->{title} || sprintf("Photo %d", $photo_number);

  my $filename = sprintf($State{filename_template}, $photo_number);

  print TOC "<li><a href=\"$filename\">$title</a>\n";

  open(HTMLFILE, ">$filename") ||
    die "Could not open $filename for writing: $!";

  select HTMLFILE;

  print "
<html>
<head>
<title>$title</title>
</head>
<body>
";

  print "<center>\n";

  print "<h2>$title</h2>\n";

  print "<table width=100%>\n";
  print "<tr>\n";

  print "<td align=center width=33%>";
  if ($photo_number != 0) {
    my $prev_filename  = sprintf($State{filename_template}, $photo_number - 1);
    print "<a href=\"$prev_filename\">Previous photo</a><p>\n";
  } else {
    print "This is the first photo";
  }
  print "</td>\n";

  print "<td align=center width=33%>";
  print "<a href=\"$State{toc_filename}\">Table of Contents</a>";
  print "</td>\n";

  print "<td align=center>";
  if ($photo_number < $number_of_photos) {
    my $next_filename  = sprintf($State{filename_template}, $photo_number + 1);
    print "<a href=\"$next_filename\">Next photo</a><p>\n";
  } else {
    print "This is the last photo";
  }
  print "</td>\n";
  print "</tr></table>\n";

  if (defined($photo->{content})) {
    print $photo->{content};
    print "<p>\n";
  }

  print "<img src=\"$photo->{image}\" width=80% height=80%><p>\n";

  print "<a href=\"$photo->{image}\">Click here for full-size image</a>\n";

  print "</center>\n";
  print "</body></html>\n";

  close(HTMLFILE);
}

print TOC "
</ol>
</body>
</html>
";

close(TOC);

exit(0);

#
# End main code
#
######################################################################

######################################################################
#
# usage_exit()
#
# Print usage and die.
#
# Arguments: Error string
# Returns: Doesn't

sub usage_exit {
  my $error_string = shift;

  print $error_string if defined($error_string);
  print "Usgae: $0 <configuration file>";
  exit(1);
}

__END__

=head1 NAME

make_slide_show.pl - Take a bunch of images and make an html slide show.

=head1 SYNOPSIS

make_slide_show.pl <config file>

=head1 QUICK START

make_slide_show takes a bunch of images and produces an html slide
show with a table of contents and a separate page for each slide that
can be walked through easily with a web browser.

make_slide_show accepts as the sole parameter the name of a
configuration file. This configuration file is an XML file with the
following format:

For example:

<slideshow title="Von's Slide Show">
  <slide image="image1.jpg" title="Slide number 1"/>
  <slide image="image2.jpg" title="Slide number 2">
  Some text describing this slide.
  </slide>
  <slide image="image3.jpg" title="Slide number 3">
  Some text describing slide 3.
  </slide>
</slideshow>

=head1 AUTHOR

Von Welch <von@vwelch.com>

=cut
