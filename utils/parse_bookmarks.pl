#!/usr/bin/perl
######################################################################
#
# parse_bookmarks
#
# $Id$
#
# parse a netscape bookmark file and output web pages.
#
######################################################################
#
# Defaults

# Options are text, flathtml, frames
$OUTPUT_MODE = "frames";

$TITLE = "Bookmarks";

######################################################################
#
# Parse commandline arguments
#

$OUTDIR = shift;

if (defined($OUTDIR)) {
  chdir($OUTDIR) ||
    die "Could not cd to $OUTDIR: $!";
}

######################################################################

# Initialize state

@FOLDERS = ();

%MY_STATE = (
	     # Name of current folder
	     "FOLDER_NAME"          =>    $TITLE,
	     # Stack of folder names
	     "FOLDERS"              =>    \@FOLDERS,
	     # A unique string identifying this folder
	     "FOLDER_ID"            =>    "0",
	     # The folder depth we're at
	     "LEVEL"                =>    0,
	     # Out output mode
	     "OUTPUT_MODE"          =>    $OUTPUT_MODE,
	     # Name of file to display in second frame
	     "SUB_FRAME_FILE"       =>    "sub.html",
	     # Name of folder to display in second frame
	     "TOOLBAR_FOLDER_NAME"  =>    "Personal Toolbar Folder",
	    );

$STATE = \%MY_STATE;

######################################################################

Init_Output($STATE);

Parse_Folder($STATE);

End_Output($STATE);

exit(0);

######################################################################
#
# Parsing routines
#

# Parse the contents of one folder. This routine is recursive.

sub Parse_Folder() {
  my $STATE = shift;

  Output_New_Folder($STATE);

  # Index of subfolders
  my $FOLDER_NUMBER = 0;

  while(<>) {
    # Regcognize an entry <A HREF="{url}" {stuff}>{title}</A>
    if (/<A HREF="([^\"]*)"[^>]*>([^<]*)<\/A>/) {
      my $URL = $1;
      my $TITLE = $2;

      Output_Entry($STATE, $TITLE, $URL);

      next;
    }

    # Recognize a folder <DT><H3 {stuff}>{titile}</H3>
    if (/<DT><H3[^>]*>([^<]*)<\/H3>/) {
      my $FOLDERS_REF = $$STATE{"FOLDERS"};

      push(@$FOLDERS_REF, $$STATE{"FOLDER_NAME"});

      $$STATE{"FOLDER_NAME"} = $1;
      $$STATE{"FOLDER_ID"} .= "_" . $FOLDER_NUMBER++;
      $$STATE{"LEVEL"}++;

      Parse_Folder($STATE);

      $$STATE{"FOLDER_NAME"} = pop(@$FOLDERS_REF);
      $$STATE{"FOLDER_ID"} =~ s/_\d+$//;
      $$STATE{"LEVEL"}--;
	   
      next;
    }

    # Recognize end of folder </DL>
    if (/<\/DL>/) {

      Output_End_Folder($STATE);

      return;
    }

    # Recognize a seperator <HR>
    if (/<HR>/) {

      Output_Separator($STATE);

      next;
    }
  }
}

######################################################################
#
# Output routines
#

# Initialize output. This routine is called only once.

sub Init_Output() {
  my $STATE = shift;

  if ($$STATE{"OUTPUT_MODE"} eq "text") {

  } elsif ($$STATE{"OUTPUT_MODE"} eq "flathtml") {
    Print_HTML_Header();

  } elsif ($$STATE{"OUTPUT_MODE"} eq "frames") {
    Print_Frames_Index($STATE);

  } else {
    print STDERR "Unknown output mode: ". $$STATE{"OUTPUT_MODE"} . "\n";
    exit(1);
  }
}

# Initial output for a new folder. This routine is called once
# at the begining of each new folder.

sub Output_New_Folder() {
  my $STATE = shift;


  if ($$STATE{"OUTPUT_MODE"} eq "text") {
    Print($STATE, "Folder: " . $$STATE{"FOLDER_NAME"});

  } elsif ($$STATE{"OUTPUT_MODE"} eq "flathtml") {

    print "<li><b>" . $$STATE{"FOLDER_NAME"} . "</b>\n";
    print "<ul>\n";

  } elsif ($$STATE{"OUTPUT_MODE"} eq "frames") {
    my $FILENAME = $$STATE{"FOLDER_ID"} . ".html";
    my $OUTPUT = $$STATE{"FOLDER_ID"};

    # Don't output anything if this is the very first folder since
    # we're not redirected to a file at this point
    if ($$STATE{"FOLDER_ID"} ne "0") {
      print "<li><b><a href=\"$FILENAME\" target=\"sub\">" .
	$$STATE{"FOLDER_NAME"} . "/</a></b>\n";
    }

    # Save current output stream
    push(@FileHandles, select(STDOUT));

    # Redirect stdout to the a file for this folder
    open($OUTPUT, ">$FILENAME") ||
      die "Could not open $FILENAME for writing: $!";

    # Is this the personal toolbar folder?
    # If so, then save it's filename
    if ($$STATE{"FOLDER_NAME"} eq $$STATE{"TOOLBAR_FOLDER_NAME"}) {
      $$STATE{"TOOLBAR_FOLDER"} = $FILENAME;
    }

    select($OUTPUT);

    print "<base target=\"sub\">\n";
    print "<h1>" . $$STATE{"FOLDER_NAME"} . "</h1>\n";
    print "<hr>\n";
    print "<ul>\n";
  }
    
}

# Finalize output for a folder. This routine is called once
# at the end of each folder.

sub Output_End_Folder() {
  my $STATE = shift;

  if ($$STATE{"OUTPUT_MODE"} eq "text") {

  } elsif ($$STATE{"OUTPUT_MODE"} eq "flathtml") {
    print "</ul>\n";

  } elsif ($$STATE{"OUTPUT_MODE"} eq "frames") {

    print "</ul>\n";

    close(select(pop(@FileHandles)));

    # Did we find a toolbar folder?
    if (defined($$STATE{"TOOLBAR_FOLDER"})) {
      # Yes, make sub frame file a link to it
      unlink $$STATE{"SUB_FRAME_FILE"};
      symlink $$STATE{"TOOLBAR_FOLDER"}, $$STATE{"SUB_FRAME_FILE"};

    } else {
      # No, make sub frame file a empty file.
      open(SUB, ">" . $$STATE{"SUB_FRAME_FILE"}) ||
	die "Could not open " . $$STATE{"SUB_FRAME_FILE"} . " for writing: $!\n";

      print SUB "<html></html>\n";

      close(SUB);

    }
  }
}

# Output an entry

sub Output_Entry() {
  my $STATE = shift;
  my $TITLE = shift;
  my $URL = shift;


  if ($$STATE{"OUTPUT_MODE"} eq "text") {
    Print($$STATE{"LEVEL"} + 1, "$TITLE $URL");

  } elsif ($$STATE{"OUTPUT_MODE"} eq "flathtml") {

    print "<li><a href=\"$URL\">$TITLE</a>\n";

  } elsif ($$STATE{"OUTPUT_MODE"} eq "frames") {

    print "<li><a target=\"_top\" href=\"$URL\">$TITLE</a>\n";
  }

}

# Output a seperator
sub Output_Separator() {
  my $STATE = shift;

  print "<HR>\n";
}

# End output. This routine is called once when all parsing is done.

sub End_Output() {
  my $STATE = shift;

  if ($$STATE{"OUTPUT_MODE"} eq "text") {

  } elsif ($$STATE{"OUTPUT_MODE"} eq "flathtml") {

    Print_End_HTML();
  }
}

# Print a string indented according to our current folder depth.
sub Print() {
  my $STATE = shift;

  print "  " x $$STATE{"LEVEL"};

  printf(@_);

  print "\n";
}

# Print the header for a html page
sub Print_HTML_Header() {
  my $STATE = shift;

  print "<html>\n";
  print "<head>\n";
  print "<title>" . $$STATE{"FOLDER_NAME"} . "</title>\n";
  print "<\head>\n";
  print "<body>\n";
}

# Give a URL and a piece of test output the html for the url
sub Print_URL() {
  my $URL = shift;
  my $TEXT = shift;

  print "<a href=\"$URL\">$TEXT</a>\n";
}

# Print the end of a html page
sub Print_End_HTML() {
  print "</body>\n";
  print "</html>\n";
}

# Create the needed index file for the frames version
sub Print_Frames_Index() {
  my $STATE = shift;

  # Create index.html
  open(INDEX, ">index.html") ||
    die "Could not open index.html for writing: $!\n";

  print INDEX "<html>\n";
  print INDEX "<head>\n";
  print INDEX "<title>" . $$STATE{"FOLDER_NAME"} . "</title>\n";
  print INDEX "</head>\n";
  print INDEX "<FRAMESET COLS=\"50%,50%\">\n";
  # Put top-level folder in left frame
  print INDEX "<FRAME src=\"0.html\">\n";
  # We need some page in the right (sub) frame or netscape never considers it
  # a frame.
  print INDEX "<FRAME src=\"" . $$STATE{"SUB_FRAME_FILE"} . "\" name=\"sub\">\n";
  print INDEX "</FRAMESET>\n";
  print INDEX "</html>\n";

  close(INDEX);
}


