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

my $NumberOfPhotos = scalar(@ARGV);
my $PhotoNumber = 0;

#
# Names of previous, current, next and first file.
#

my $PreviousFilename = undef;
my $CurrentFilename = undef;
my $NextFilename = shift;
my $FirstFilename = undef;

# Image size
my $Height = "200";
my $Width = "320";

######################################################################
#
# Get names of photos
#
# If present use names on command line, else read file slide_show

my $Photos = ();

if (scalar(@ARGV)) {
  @Photos = @ARGV;

} elsif ( -f "slide_show" ) {
  print "Reading photos from file \"slide_show\"...\n";

  open(IN, "<slide_show") || die "Could not open slide_show for reading: $!";

  while (<IN>) {
    chomp;
    my ($filename, $title) = split(' ', $_, 2);
    push(@Photos, $filename);
    push(@Titles, $title);
  }

  close(IN);
}

$NumberOfPhotos = scalar(@Photos);

######################################################################
#
# Main loop
#

open(TOC, ">toc.html") ||
  die "Could not open toc.html for writing: $!";

  print TOC "
<html>
<head>
<title>Table of contents</title>
</head>
<body>
<h1>Table of contents</h1>
<ol>
";

for($CurrentFilename = shift(@Photos),
    $NextFilename = shift(@Photos),
    $PhotoNumber = 1;
    defined($CurrentFilename);
    $PreviousFilename = $CurrentFilename,
    $CurrentFilename = $NextFilename,
    $NextFilename = shift(@Photos),
    $PhotoNumber++) {

  $FirstFilename = $CurrentFilename if !defined($FirstFilename);

  # Get names of html files associated with image files.
  my $current_filename = html_filename($CurrentFilename);
  my $previous_filename = html_filename($PreviousFilename);
  my $next_filename = html_filename($NextFilename);
  my $first_filename = html_filename($FirstFilename);
  my $text_filename = text_filename($CurrentFilename);

  my $title = shift(@Titles);

  print TOC "<li><a href=\"$current_filename\">$title</a>\n";

  open(HTMLFILE, ">$current_filename") ||
    die "Could not open $html_filename for writing: $!";

  select HTMLFILE;

  print "
<html>
<head>
<title>$title ($PhotoNumber/$NumberOfPhotos) $CurrentFilename</title>
</head>
<body>
";

  print "<center>\n";

  print "<h2>$title</h2>\n";

  print "<table width=100%>\n";
  print "<tr>\n";

  print "<td align=center width=33%>";
  if (defined($PreviousFilename)) {
    print "<a href=\"$previous_filename\">Previous photo</a><p>\n";
  } else {
    print "This is the first photo";
  }
  print "</td>\n";

  print "<td align=center width=33%>";
  print "<a href=\"toc.html\">Table of Contents</a>";
  print "</td>\n";

  print "<td align=center>";
  if (defined($NextFilename)) {
    print "<a href=\"$next_filename\">Next photo</a><p>\n";
  } else {
    print "This is the last photo";
  }
  print "</td>\n";
  print "</tr></table>\n";

  if ( -f $text_filename) {
    open(TXT, "<$text_filename") ||
      die "Could not open $text_filename for reading: $!";

    while (<TXT>) {
      print;
    }

    close(TXT);

    print "<p>\n";
  }

  print "<img src=\"$CurrentFilename\"><p>\n";

  #print "<a href=\"$CurrentFilename\">Click here for full-size image</a>\n";

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

symlink(html_filename($FirstFilename), "index.html");

exit(0);

#
# End main code
#
######################################################################

######################################################################
#
# html_filename
#
# Given the name of the image file return the name of the html
# file associated with it.
#
# Arguments: Image filename
# Returns: HTML filename

sub html_filename {
  my $html_filename = shift;

  $html_filename =~ s/\.[^.]+$/.html/;

  return $html_filename;
}

######################################################################
#
# text_filename
#
# Given the name of the image file return the name of the text
# file associated with it.
#
# Arguments: Image filename
# Returns: text filename

sub text_filename {
  my $text_filename = shift;

  $text_filename =~ s/\.[^.]+$/.txt/;

  return $text_filename;
}
