#!/usr/local/bin/perl
######################################################################
#
# acl_edit
#
# AFS acl editor
#
# $Id$
#
######################################################################

$FS = "fs";

$SET_ACL_CMD = "sa";

$LIST_ACL_CMD = "la";

$PROMPT = "acl_edit> ";

$VERBOSE = 1;

######################################################################
#
# Set $MYNAME equal to basename of this script
#

$0 =~ /.*\/([^\/]+)$/;

$MYNAME = $1;

######################################################################

%ACL_ALIASES = (
		"read" => "rl",
		"all" => "rlidwka",
		"write" => "rlidwk"
	       );

%USER_ALIASES = (
		 "authuser" => "system:authuser",
		 "anyuser" => "system:anyuser"
		);

%FUNCTIONS = (
	      "?" => \&HELP,
	      "a" => \&SET_ACL,
	      "add" => \&SET_ACL,
	      "cd" => \&CHANGE_DIR,
	      "d" => \&DELETE_ACL,
	      "del" => \&DELETE_ACL,
	      "delete" => \&DELETE_ACL,
	      "help" => \&HELP,
	      "l" => \&LS,
	      "ls" => \&LS,
	      "p" => \&PRINT_ACLS,
	      "print" => \&PRINT_ACLS,
	      "pwd" => \&PRINT_DIR,
	      "tree" => \&TREE,
	      "q" => \&QUIT,
	      "quit" => \&QUIT,
	    );


$HELP_STRING = "
a|add <user> <acl>                      Add an acl
cd <dir>                                Change directory
d|del|delete <user>                     Delete an acl
help|?                                  Print this message
l|ls                                    List subdirs of current directory
p|print                                 Print acls of current directory
pwd                                     Print name of current directory
tree <cmd>                              Run command on directory tree
q|quit                                  Quit

";
     

######################################################################
#
# Get out starting directory
#

use Cwd;

$DIRECTORY = PARSE_DIRNAME(cwd());

if (defined($DIR = shift)) {
	my $NEW_DIR = CD($DIRECTORY, $DIR);

	$DIRECTORY = $NEW_DIR
	  if defined($NEW_DIR);
}

######################################################################
#
# Parse command line
#

if (defined(shift)) {
	ERROR_MSG("Ignoring extra arguments on command line");
}


######################################################################
#
# Main Code
#

while(1) {
  print $PROMPT;

  $INPUT = <STDIN>;

  if (!defined($INPUT)) {
    last;
  }

  @ARGS = split(/[\ \t\n]+/, $INPUT);

  $CMD = $ARGS[0];

  $FUNCTION = $FUNCTIONS{$CMD};

  if (defined($FUNCTION)) {
    &$FUNCTION($DIRECTORY, \@ARGS);
  } else {
    &ERROR_MSG("Unknown command \"$CMD\"");
  }
}

exit 0;

#
# End Main Code
#
######################################################################

######################################################################
#
# Top level subroutines
#

######################################################################
#
# Add an acl to current directory
#

sub SET_ACL {
  my $DIR = shift;
  my $ARGS = shift;
  my $DO_SUBDIRS = 0;

  if ($#$ARGS != 2) {
    ERROR_MSG("Usage: " . $$ARGS[0] . " <user> <acl>");
    return 0;
  }

  my $USER = PARSE_USER($$ARGS[1]);
  my $ACL = ALIAS_TO_ACL($$ARGS[2]);

  VERBOSE_MSG("Setting " . $USER . "'s permissions to $ACL in $DIR");

  my $CMD = $FS;
  $CMD .= " " . $SET_ACL_CMD;
  $CMD .= " \"" . $DIR . "\"";
  $CMD .= " " . $USER;
  $CMD .= " " . $ACL;

  if (system($CMD) != 0) {
    return 0;
  }

  return 1;
}

######################################################################
#
# Change directory
#
# Modified $DIRECTORY
#

sub CHANGE_DIR {
  my $DIR = shift;
  my $ARGS = shift;

  if ($#$ARGS > 1) {
    ERROR_MSG("Usage: " . $$ARGS[0] . " [<directory>]");
    return 0;
  }

  my $NEW_DIR = CD($DIRECTORY, $$ARGS[1]);

  return 0
	 if (!defined($NEW_DIR));

  $DIRECTORY = $NEW_DIR;
  &VERBOSE_MSG($DIRECTORY);

  return 1;
}

######################################################################
#
# Add an acl to current directory
#

sub DELETE_ACL {
  my $DIR = shift;
  my $ARGS = shift;

  if ($#$ARGS != 1) {
    ERROR_MSG("Usage: " . $$ARGS[0] . " <user>");
    return 0;
  }

  my $USER = PARSE_USER($$ARGS[1]);

  VERBOSE_MSG("Deleting " . $USER . "'s permissions in $DIR");

  my $CMD = $FS;
  $CMD .= " " . $SET_ACL_CMD;
  $CMD .= " \"" . $DIR . "\"";
  $CMD .= " " . $USER;
  $CMD .= " none";

  if (system($CMD) != 0) {
    return 0;
  }

  return 1;
}


######################################################################
#
# Print help information
#

sub HELP {
  print $HELP_STRING;
}

######################################################################
#
# Print a list of subdirectories
#

sub LS {
  my $DIR = shift;
  my $ARGS = shift;

  if ($#ARGS != 0) {
    ERROR_MSG("Usage: " . $$ARGS[0]);
    return 0;
  }

  my @SUBDIRS = GET_SUBDIRS($DIR);

  for $SUBDIR (@SUBDIRS) {
    print $SUBDIR . "\n";
  }

  return 1;
}

######################################################################
#
# Print a acls list
#

sub PRINT_ACLS {
  my $DIR = shift;
  my $ARGS = shift;

  if ($#ARGS != 0) {
    ERROR_MSG("Usage: " . $$ARGS[0]);
    return 0;
  }

  my %ACLS = GET_ACLS($DIR);

  print "ACLs for $DIR:\n";
  foreach $USER (sort({$a cmp $b} keys(%ACLS))) {
    printf("%-50s %s\n", $USER, ACL_TO_ALIAS($ACLS{$USER}));
  }

  return 1;
}

######################################################################
#
# Print our current directory
#

sub PRINT_DIR {
  my $DIR = shift;
  my $ARGS = shift;
 
  if ($#ARGS != 0) {
    ERROR_MSG("Usage: " . $$ARGS[0]);
    return 0;
  }

  print $DIR . "\n";

  return 1;
}

######################################################################
#
# Perform an action on the whole directory tree
#

sub TREE {
  my $DIR = shift;
  my $ARGS = shift;

  if ($#ARGS < 1) {
    ERROR_MSG("Usage: "  . $$ARGS[0] . " <cmd> [<args>]");
    return 0;
  }

  # Remove current function name
  shift(@$ARGS);

  # Get function name to call
  my $CMD = $$ARGS[0];

  $FUNCTION = $FUNCTIONS{$CMD};

  if (!defined($FUNCTION)) {
    &ERROR_MSG("Unknown command \"$CMD\"");
    return 0;
  }

  return DO_TREE($FUNCTION, $DIR, $ARGS);
}

######################################################################
#
# Quit
#

sub QUIT {
  exit(0);
}

######################################################################
#
# Support routines
#

######################################################################
#
# Call a function for each directory in a tree. This function is
# recursive.
#

sub DO_TREE {
  my $FUNCTION = shift;
  my $DIR = shift;
  my $ARGS = shift;


  # Do current directory
  if (!&$FUNCTION($DIR, $ARGS)) {
    return 0;
  }

  my @SUBDIRS = &GET_SUBDIRS($DIR);

  for $SUBDIR (@SUBDIRS) {
    my $NEW_DIR = $DIR . "/" . $SUBDIR;

    if (!DO_TREE($FUNCTION, $NEW_DIR, $ARGS)) {
      return 0;
    }
  }

  return 1;
}


######################################################################
#
# Get acls for current directory
#

sub GET_ACLS {
  my $DIR = shift;

  my $CMD = $FS;

  my %ACLS;

  $CMD .= " " . $LIST_ACL_CMD;
  $CMD .= " \"" . $DIR . "\"";

  if (!open(FS, "$CMD |")) {
    ERROR_MSG("Could not execute $CMD");
    return undef;
  }

  while(<FS>) {
    if (/  ([\w:\.]+) (\w+)/) {
      $ACLS{$1} = $2;
    }
  }

  close(FS);

  return %ACLS;
}


######################################################################
#
# Convert a acl string to a human readable alias
#

sub ACL_TO_ALIAS {
  my $ACL = shift;

  foreach $ALIAS (keys(%ACL_ALIASES)) {
    if ($ACL_ALIASES{$ALIAS} eq $ACL) {
      return $ALIAS;
    }
  }

  # None found
  return $ACL;
}


######################################################################
#
# Convert an alias strin to an acl string
#

sub ALIAS_TO_ACL {
  my $ALIAS = shift;

  if (defined($ACL_ALIASES{$ALIAS})) {
    return $ACL_ALIASES{$ALIAS};
  }

  return $ALIAS;
}


######################################################################
#
# Convert a user alias to it's real name
#

sub PARSE_USER {
  my $USER = shift;

  if (defined($USER_ALIASES{$USER})) {
    return $USER_ALIASES{$USER};
  }

  return $USER;
}


######################################################################
#
# Print an error message
#

sub ERROR_MSG {
  my $MSG = shift;

  print STDERR $MYNAME . ": " . $MSG;

  if ($MSG !~ /\n$/) {
    print STDERR "\n";
  }
}

######################################################################
#
# Print a message if we're in verbose mode
#

sub VERBOSE_MSG {
  my $MSG = shift;

  if ($VERBOSE == 0) {
    return;
  }

  print $MSG;

  if ($MSG !~ /\n$/) {
    print "\n";
  }
}

######################################################################
#
# Parse a directory name to a absolute pathname
#

sub PARSE_DIRNAME {
  my $DIR = shift;

  # Convert "~" in directory name
  $DIR =~ s/\~/$ENV{"HOME"}/;

  return $DIR;
}

######################################################################
#
# Given current directory and CD argument, return new directory
# name. CD argument can be null or "" indicating a cd to home
# directory. Return undef on error.
#

sub CD {
	my $CURRENT_DIR = shift;
	my $CD = shift;
	 
	my $NEW_DIR;

	if (!defined($CD)) {
		# CD to home directory
		$NEW_DIR = $ENV{"HOME"};

	} else {
		my $ARG = PARSE_DIRNAME($CD);

		if ($ARG =~ /^\//) {
			# Absolute path
			$NEW_DIR = $ARG;
      
		} else {
			# Relative path
		 
			# Code stolen from Cwd.pm
			my @COMPONENTS = split(/\//, $DIRECTORY);
			my @NEW_COMPONENTS = split(/\//, $ARG);
			
			foreach $COMPONENT (@NEW_COMPONENTS) {
				if ($COMPONENT eq ".") {
					next;
				}
				
				if ($COMPONENT eq "..") {
					pop(@COMPONENTS);
					next;
				}

				push(@COMPONENTS, $COMPONENT);
			}
			
			$NEW_DIR = join('/', @COMPONENTS) || '/';
		}
	}

	if ( ! -d $NEW_DIR) {
		&ERROR_MSG("Bad directory: $NEW_DIR");
		return undef;
	}

	return $NEW_DIR;
}



######################################################################
#
# Return all the subdirectories of a given directory
#
# Symlinks, "." and ".." are ignored.
#

sub GET_SUBDIRS {
  my $DIR = PARSE_DIRNAME(shift);


  if (!opendir(DH, $DIR)) {
    &ERROR_MSG("Could not open directory $DIR: $!");
    return ();
  }

  my $FILE;
  my @SUBDIRS = ();

  while (defined($FILE = readdir(DH))) {
    my $FULLNAME = $DIR . "/" . $FILE;

    # Ignore "." and ".."
    if (($FILE eq ".") || ($FILE eq "..")) {
      next;
    }

    # Ignore symbolic links
    if (-l $FULLNAME) {
      next;
    }

    # Ignore non-directories
    if (!-d $FULLNAME) {
      next;
    }

    push(@SUBDIRS, $FILE);
  }

  closedir(DH);

  return @SUBDIRS;
}

