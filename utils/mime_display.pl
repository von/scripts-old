#!/usr/bin/perl -w
######################################################################
#
# mime_display
#
# Given a content type and file name on the command line, call the
# appropriate program to display the file.
#
# $Id$
#
######################################################################

my $content_type = shift(@ARGV);

my $filename = shift;

if (!defined($content_type) ||
    !defined($filename)) {
  print STDERR "Usage: $0 <content type> <filename>\n";
  exit 1;
}

######################################################################

# Windows mappings
my %mapping =
  (
   "application/msword" => "winword",
   "application/rtf" => "winword",
   "application/zip" => "winzip32",
   "application/pdf" => "acrord32",
   "application/x-mspowerpoint" => "powerpnt",
   "application/vnd.ms-powerpoint" => "powerpnt",
   "video" => "wmplayer",
   "image/bitmap" => "mspaint",
   "image" => "netscp6",
   "text" => "netscp6",
  );

######################################################################

# Windows paths
@PATHS = ("C:\\Program Files\\Adobe\\Acrobat 5.0\\Reader",
	  "C:\\Program Files\\WinZip",
	  "C:\\Program Files\\Microsoft Office\\Office",
	  "C:\\Program Files\\Windows Media Player",
	  "C:\\Program Files\\Netscape\\Netscape 6",
	  "c:\\WINNT\\system32",
	 );

$ENV{PATH} = join(';', $ENV{PATH}, @PATHS);

print $ENV{PATH} . "\n";

######################################################################

type: foreach $type (keys(%mapping)) {
  if ($content_type =~ /$type/i) {
    $command = $mapping{$type};
    last type;
  }
}

if (!defined($command)) {
  print STDERR "Unknown content type \"$content_type\"\n";
  exit 1;
}

# Substitute for or append filename
if ($command =~ /%f/) {
  $command =~ s/%f/$filename/g;
} else {
  $command .= " " . $filename;
}

exec($command) || die "Exec of $command failed: $!";

		
