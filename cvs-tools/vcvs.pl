#!/usr/local/bin/perl
######################################################################
#
# vcvs - Von's cvs script
#
# Script for doing stuff with CVS.
#
# $Id$
#
######################################################################

require 5.001;

use Cwd;
use Cwd 'chdir';
use File::Basename;
use File::Spec;
use Text::ParseWords;

######################################################################
#
# Constants
#

%Binaries = (
	     autoheader            => "autoheader",
	     autoconf              => "autoconf",
	     cd                    => "cd",
	     cvs                   => "cvs",
	     gzip                  => "gzip",
	     rm                    => "rm",
	     tar                   => "tar",
	    );

%Functions = (
	     );

######################################################################
#
# Configurables
#

%Configuration = (
		  configuration_file        => undef,
		  context_diff              => 1,
		  cvsroot                   => undef,
		  end_tag                   => undef,
		  ignore_rcs_keywords       => 1,
		  module                    => undef,
		  my_name                   => undef,
		  nonexistant_files_empty   => 1,
		  start_tag                 => undef,
		  starting_dir              => undef,
		  tmpdir                    => "/tmp",
		 );

######################################################################
#
# Setup
#

$Configuration{my_name} = basename($0);

# Get starting directory
$Configuration{starting_dir} = cwd();

######################################################################
#
# Parse commandline options
#

use Getopt::Std;

my %option;

getopts('c:', \%option);

$Configuration{configuration_file} = $option{c}            if $option{c};

my $operation = shift;

defined($operation) || usage_and_exit("Operation expected");

######################################################################
#
# Read the configuration file
#

if (!defined($Configuration{configuration_file})) {
  defined($ENV{HOME}) || error("Can't determine HOME directory.");

  $Configuration{configuration_file} = File::Spec->catfile($ENV{HOME},
							   ".vcvs",
							   "config");
} else {
  # If user specified a configuration file, it must exist
  (-f $Configuration{configuration_file}) ||
    error("Configuration file %s does not exist",
	  Configuration{configuration_file});
}

(-f Configuration{configuration_file}) &&
  read_configuration($Configuration{configuration_file});

######################################################################
#
# Execute operation
#

my $function = $Functions{$operation};

defined($function) || error("Unknown operation \"$operation\"");

my $exit_value = &$function($operation, @ARGV);

exit($exit_value);

#
# End main code
#
######################################################################
######################################################################
######################################################################
#
# Support Functions
#

#
# error
#
# Print an error message and exit.
#
# Arguments: Format, [arguments...]
# Returns: Doesn't

sub error {
  warning(@_);
  exit(1);
}



#
# make_tmp_dir()
#
# Create a temporary directory and return it's path.
#
# Arguments: None
# Returns: Path, calls error() on error and dies

sub make_tmp_dir {
  my $path_base = sprintf("%s/%s.$$",
		     $Configuration{tmpdir},
		     $Configuration{my_name});

  my $path = $path_base;

  my $index = 0;

  while (-e $path) {
    $path = sprintf("%s.%d", $path_base, $index++);
  }

  mkdir($path, 0700) || error("Failed to create temporary directory $path: $!");

  return $path;
}

#
# usage_and_exit()
#
# Print an error message, display usage and exit.
#
# Arguments: Format, [arguments...]
# Returns: Doesn't

sub usage_and_exit {
  warning(@_);

  print STDERR "

Usage: $Configuration{my_name} [<options>] <operation> [<arguments>]

Options are:
   -c <configuration file>       Specify configuration file to use instead
                                 of ~/.vcvs/config

Operations:
";

  exit(1);
}

#
# warning
#
# Print a warning message to the user.
#
# Arguments: Format, [arguments...]
# Returns: True

sub warning {
  my $format = shift;

  chomp($format);

  printf(STDERR $format . "\n", @_);

  return 1;
}

######################################################################
######################################################################
#
# Configuration file parsing
#

sub read_configuration {
  my $file = $Configuration{configuration_file};

  open(CONF_FILE, "<$file") || error("Could not open configuration file %s: $!",
				     $file);

  my %module_options = (
			cvsroot                   => "string",
			tag                       => "string",
			post_export_command       => "string",
		       );

 line: while(<CONF_FILE>) {

    chomp;

    # Deal with backslash-escaped carraige returns
    if (s/\\$//) {
      $_ .= <CONF_FILE>;
      redo line unless eof();
    }

    # Ignore comments
    /^\s*\#// && next line;

    # Ignore blank lines
    /^\s*$/ && next line;

    my @tokens = quotewords('\s+', 0, ($_));

    my $keyword = shift(@tokens);

    if ($keyword eq "module") {
      my $module = shift(@tokens);

      if (!defined($module)) {
	warning("Missing module name on line $. of $file");
	next line;
      }

      # Parse module options
    module_line: while(defined(my $arg = shift(@tokens))) {
	
######################################################################
######################################################################
#
# Operations
#




# XXX

######################################################################
#
# HandleExport
#
# Handle an export request.
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub HandleExport {

  if (!defined($TAG1)) {
    $TAG1 = "-D now";
  }

  if (defined($TAG2)) {
    WarnMsg("Ignoring unneeded second tag");
  }

  my $DIR = ExportModule($MODULE, $TAG1);

  if (!defined($DIR)) {
    return 0;
  }

  # Tar up and zip the exported module back in the original directory
  my $GZIPFILE = $DIR . ".tar.gz";
  my $CMD = "";

  $CMD .= "$TAR cfv - $DIR | ( $CD $STARTING_DIR ; $GZIP > $GZIPFILE )";

  if (RunCmd($CMD) != 0) {
    return 0;
  }

  return 1;
}


######################################################################
#
# HandlePatch
#
# Handle a making a patch.
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub HandlePatch {
  my $ARGS = "";

  if ($IGNORE_RCS_KEYWORDS) {
    $ARGS .= "-kk ";
  }

  if ($NONEXISTANT_FILES_EMPTY) {
    # XXX
  }

  if ($CONTEXT_DIFF) {
    $ARGS .= "-c ";
  }

  my $PATCHFILE = $STARTING_DIR . "/" . $MODULE . "_patch";

  if (defined($TAG1)) {
    $PATCHFILE .= "_" . TagToString($TAG1);
  }

  if (defined($TAG2)) {
    $PATCHFILE .= "_" . TagToString($TAG2);
  }

  if (CVSCmd("rdiff", $ARGS, $TAG1, $TAG2, $MODULE, " > $PATCHFILE") != 0) {
    return 0;
  }

  return 1;
}

######################################################################
#
# ParseOptions
#
# Parse command line options. We have our own function here because
# we need to be able to handle multiple occurances of '-r' and '-D'
# and none of the perl modules seem to do this.
#
# Arguments: None (works directly on @ARGV)
# Returns: 1 on success, 0 on error

sub ParseOptions {
  my $STATUS = 1;

 Arg: while(($ARGV[0] =~ /^-(\w)$/) ||
	($ARGV[0] =~ /^--(\w+)$/)) {
    my $ARG = $1;
    my $STRING = shift(@ARGV);
    my $VALUE = undef;

    # Need a value?
    if (($ARG eq "d") || ($ARG eq "cvsroot") ||
	($ARG eq "r") || ($ARG eq "D")) {
      $VALUE = shift(@ARGV);

      if (!defined($VALUE)) {
	ErrorMsg($STRING . " requires a value");
	$STATUS = 0;
	next Arg;
      }
    }

    if (($ARG eq "d") || ($ARG eq "cvsroot")) {
      $CVSROOT = $VALUE;
      next Arg;
    }

    if (($ARG eq "r") || ($ARG eq "D")) {
      my $TAG = $STRING . " " . $VALUE;

      if (!defined($TAG1)) {
	$TAG1 = $TAG;

      } elsif (!defined($TAG2)) {
	$TAG2 = $TAG;

      } else {
	WarnMsg("Too many tags specified - ignoring extra");
      }
      next Arg;
    }


    ErrorMsg("Unknown option \"" . $ARG . "\"");
    $STATUS = 0;
  }

  return $STATUS;
}


######################################################################
#
# ExportModule
#
# Export a module, returning the directory it was exported into
# or undef on error.
#
# Arguments: <module name>, <export tag>
# Returns: <exported directory name>
#

sub ExportModule {
  my $MODULE = shift;
  my $TAG = shift;

  my $DIRNAME = $MODULE . "_" . TagToString($TAG);

  if ( -e $DIRNAME ) {
    ErrorMsg("Error trying to check out $MODULE: $DIRNAME already exists");
    return undef;
  }

  if (CVSExport($MODULE, $TAG, $DIRNAME) == 0) {
    ErrorMsg("Error exporting $MODULE");
    return undef;
  }

  if (Autoconf($DIRNAME) == 0) {
    ErrorMsg("Error rebuilding autoconf stuff for $MODULE");
    return undef;
  }

  return $DIRNAME;
}


######################################################################
#
# TagToString
#
# Convert a cvs tag into a human readable string.
#
# Arguments: <tag>
# Returns: <string>
#

sub TagToString {
  my $TAG = shift;

  if ($TAG eq "-D now") {
    my @LOCALTIME = localtime();
    my $DATESTRING = sprintf("%02d%02d%02d",
			     $LOCALTIME[5],
			     $LOCALTIME[4] + 1,
			     $LOCALTIME[3]);

    return $DATESTRING;
  }

  if ($TAG =~ /-D (\S+)/) {
    my $DATE = $1;
    my ($YEAR, $MON, $DAY);

    # mm/dd/yyyy
    if ($DATE =~ /(\d?\d)\/(\d?\d)\/(\d+)/) {
      # Right 2 insignifigant digits of the year
      $YEAR = substr($3, length($3) - 2, 2);
      $MON = $1;
      $DAY = $2;

    }

    return sprintf("%02d%02d%02d", $YEAR, $MON, $DAY);
  }

  if ($TAG =~ /-r (\w+)/) {
    return $1;
  }

  ErrorMsg("Could not parse tag \"" . $TAG . "\"");

  return "unknown";
}



######################################################################
#
# CVSExport
#
# Export a module from CVS.
#
# Arguments: <module>, <tag or date>, [<target directory>]
# Returns: 1 on success, 0 on error
#

sub CVSExport {
  my $MODULE = shift;
  my $TAG = shift;
  my $TARGET_DIR = shift;

  if (defined($TARGET_DIR)) {
    $TARGET_DIR = "-d $TARGET_DIR";
  }

  if (CVSCmd("export", $TARGET_DIR, $TAG, $MODULE) != 0) {
    return 0;
  }

  return 1;
}


######################################################################
#
# Autoconf
#
# Rebuild any needed autoconf-related files in a tree. This function
# is renterant.
#
# Arguments: <path>, [<localdir>]
# Returns: 1 on success, 0 on error
#

sub Autoconf {
  my $PATH = shift;
  my $LOCALDIR = shift;


  # Make sure $PATH is absolute
  if ($PATH !~ /^\//) {
    my $CWD = cwd();
    $PATH = $CWD . "/" . $PATH;
  }

  VerboseMsg("Checking for autoconf stuff in $PATH");

  # If aclocal.m4 exists in this directory then it shoudl be used
  # as the localdir for this directory and all beneath it.
  if ( -f $PATH . "/aclocal.m4" ) {
    $LOCALDIR = $PATH;
  }

  # Should we run autoheader
  if ( -f $PATH . "/acconfig.h" &&
       ! -f $PATH . "/config.h.in" ) {

    my $CMD = "";
    $CMD .= "$CD $PATH ; $AUTOHEADER";
    $CMD .= " --localdir=" . $LOCALDIR if defined($LOCALDIR);

    VerboseMsg("Running autoheader in $PATH");

    if (RunCmd($CMD) != 0) {
      return 0;
    }
  }

  # Should we run autoconf
  if ( -f $PATH . "/configure.in" &&
       ! -f $PATH . "/configure" ) {

      
    my $CMD = "";
    $CMD .= "$CD $PATH ; $AUTOCONF";
    $CMD .= " --localdir=" . $LOCALDIR if defined($LOCALDIR);

    VerboseMsg("Running autoconf in $PATH");

    if (RunCmd($CMD) != 0) {
      return 0;
    }
  }

  # Recurse into subdirectories
  my @FILES = DIRECTORY($PATH);

 File: for $FILE (@FILES) {
    my $NEW_PATH = $PATH . "/" . $FILE;

    next File if ( ! -d $NEW_PATH);

    if (Autoconf($NEW_PATH, $LOCALDIR) == 0) {
      return 0;
    }
  }

  return 1;
}

    
######################################################################
#
# DIRECTORY
#
# Read all filenames in a directory and return an array containing
# them. Ignores "." and "..".
#
# Arguments: [<Path>]
# Returns: Array or under on error.
#

sub DIRECTORY {
    my $DIRECTORY = shift;

    $DIRECTORY = "."
	if !$DIRECTORY;

    my $DH;

    my $FILE;
    my @FILES = ();


    opendir(DH, $DIRECTORY) ||
      return undef;

    while(defined($FILE = readdir(DH))) {
	next
	    if (($FILE eq ".") || ($FILE eq ".."));

	push(@FILES, $FILE);
    }

    closedir(DH);

    return @FILES;
}


######################################################################
#
# CVSCmd
#
# Execute a CVS command.
#
# Arguments: <operation>, <arguments...>
# Returns: <return code of cvs command>

sub CVSCmd {
  my $OP = shift;

  my $CMD = "";
  $CMD .= $CVS;
  $CMD .= " -d $CVSROOT" if defined($CVSROOT);
  $CMD .= " $OP ";
  $CMD .= join(' ', @_);

  return RunCmd($CMD);
}

######################################################################
#
# RunCmd
#
# Run a command and return it's return code.
#
# Arguments: <command>
# Returns: <return code of command>

sub RunCmd {
  my $CMD = shift;

  VerboseMsg($CMD);

  system($CMD);

  $RETURN_CODE = $? >> 8;

  return $RETURN_CODE;
}


######################################################################
#
# VerboseMsg
#
# Display a message if we are displaying verbose messages.
#

sub VerboseMsg {
  # XXX check for verbose mode
  Msg(@_);
}

######################################################################
#
# Msg
#
# Display a message
#

sub Msg {
  my $FORMAT = shift;

  # Append a CR if needed
  $FORMAT .= "\n" if ($FORMAT !~ /\n$/);

  printf($FORMAT, @_);
}

######################################################################
#
# WarnMsg
#
# Display a warning message
#

sub WarnMsg {
  ErrorMsg(@_);
}

######################################################################
#
# ErrorMsg
#
# Display an error  message
#

sub ErrorMsg {
  my $FORMAT = shift;

  # Append a CR if needed
  $FORMAT .= "\n" if ($FORMAT !~ /\n$/);

  printf(STDERR $FORMAT, @_);
}
