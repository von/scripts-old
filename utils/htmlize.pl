#!/usr/local/bin/perl -w
######################################################################
#
# htmlize
#
# Take a plain text document and display nicely in netscape.
#
# Security Risk: Stores email in /tmp, potentially world-readable.
#
######################################################################
#
# Parse command line arguments
#

use Getopt::Std;

my %opts;

getopts('hm', \%opts);

if ($opts{h}) {
  usage();
  exit(0);
}

######################################################################

$outfile="/tmp/htmlize.$$";

local *OUTFILE;

open(OUTFILE, ">$outfile") ||
  die "Error opening output file $outfile: $!";

print OUTFILE "<html>\n";


while(<>) {
  # Filter email headers if so requested
  $opts{m} && filter_email_headers() && next;

  # Escape special characters
  s?\<?&lt;?g;
  s?\>?&gt;?g;

  # Deal with urls
  s?(ftp://[^ &]+)?<a href="$1">$1</a>?g;
  s?(http://[^ &]+)?<a href="$1">$1</a>?g;

  # Add linebreaks at end of lines
  s?$?</br>?;

  print OUTFILE;
}

print OUTFILE "</html>\n";

close(OUTFILE);


system("netscape -noraise -remote \"openURL(file://$outfile, new-window)\"");

# Would like to unlink the file here, but 'netscape -remote' returns
# immediately and then we would be prevented from going back to the
# file if we wanted to.

# Return 0 so mutt doesn't request a keystroke
exit(0);

######################################################################
#
# Subroutines
#

sub usage {
  print"
Usage: htmlize [<options>] [files...]

Options are:
  -h               Print usage and exit.
  -m               Treat processed file as email message.
";
}


# filter_email_headers()
#
# Returns 1 if the current line should be filtered.

BEGIN {
  # Are we currently in the headers portion of the email
  my $in_headers = 1;

  # Some headers span multiple lines, for these we need to keep track
  # of wether or not we are printing this header.
  my $print_state = 0;

  sub filter_email_headers() {
    return 0 unless $in_headers;
    
    # Blank line indicates end of headers
    if (/^\s*$/) {
      $in_headers = 0;
      return 0;
    }
    
    # Is this a header start line?
    if (/^\S+:/) {
      # Print only certain headers
      if (/^Date:/ ||
	  /^To:/ ||
	  /^From:/ ||
	  /^Subject:/ ||
	  /^Cc:/) {
	$print_state = 1;
	return 0;
	
      } else {
	$print_state = 0;
	return 1;
      }
    }
    
    # This line is a contination of a previous header, print based on
    # state
    return !$print_state;
  }
}

__END__

=head1 NAME

htmlize - Take a plain text document, convert it to html and send to netscape.

=head1 SYNOPSIS

htmlize [<options>] [<files...>]

=head1 DESCRIPTION

htmlize is a tool designed to convert a plain text document into html
and then send to a web browser for viewing. The intent is that it is
to be used with programs like mutt for view email with URLs.

htmlize will act on any filenames given on the commandline or
on standard in, if no filenames are given.

=head1 OPTIONS

=over 4

The following command line options are available:

=item B<-h>

Print usage and exit.

=item B<-m>

Treat the given text as email. Currently this means that lots of
headers will be filtered.

=back

=head1 USING WITH MUTT

By default mutt will use the urlview program. You can chance this
behavior by adding the following lines to your .muttrc file:

  macro index \cb |"htmlize -m"\n
  macro pager \cb |"htmlize -m"\n

You will probably also want to set nowait_key so you won't be
requested for a key press after piping to htmlize.

=head1 FILES

/tmp/htmlize.*      Temporary files

=head1 BUGS

=over 4

=item Temporary files are not cleaned up.

The problem is that if htmlize removed the temporary file, then you can't
go back to viewing it in netscape if you leave it (i.e. follow a link
in the file and then click the Back button.)

=head1 AUTHOR

  Von Welch <vwelch@ncsa.uiuc.edu>

