#!/usr/local/bin/perl
######################################################################
#
# make_slide_table.pl
#
# Make a table of miniatiure photos which can be clicked on to
# view the full image.
#
# $Id$
#
######################################################################

my $NumberOfPhotos = scalar(@ARGV);
my $PhotoNumber = 0;

my $Width = 4;

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
# Main Code
#

open(TABLE, ">table.html") ||
  die "Could not open table.html for writing: $!";

print TABLE "
<html>
<head>
<title></title>
</head>
<body>
<table width=100%>
";

for ($Image = shift(@Photos),
     $ImageNumber = 0;
     defined($Image);
     $Image = shift(@Photos),
     $ImageNumber++) {

  print TABLE "</tr>\n" if (($ImageNumber % $Width == 0) &&
			    ($ImageNumber != 0));

  print TABLE "<tr>\n" if ($ImageNumber % $Width == 0);

  print TABLE "
<td><a href=\"$Image\"><img src=\"$Image\" width=100></a></td>\n";
}

  print TABLE "</tr>\n" unless ($ImageNumber % $Width == 0);


print TABLE "
</table>
</body>
</html>
";

close(TABLE);

exit(0);

#
# End Code
#
######################################################################
