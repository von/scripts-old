#!/usr/local/bin/perl
######################################################################
#
# buildall
#
# Build a package on multiple systems.
#
# You man generate a man page for buildall by running pod2man
# on this file.
#
# $Id$
#
######################################################################

require 5.001;

use Getopt::Std;
use Sys::Hostname;

$VERSION = "0.1.7";

######################################################################
#
# Find configuration files. May be overridden later by commandline
# options
#

$BUILDALL_DIR = FindBuildallDir();

$LOCAL_CONF_FILE = FindConfFile();

#
# Initialize configuration
#

%CONFIG = (
	   # Configuration files and directories
	   BUILDALL_DIR      =>    $BUILDALL_DIR,
	   LOCAL_CONF_FILE   =>    $LOCAL_CONF_FILE,

	   # Building options
	   WORKING_DIR       =>    undef,
	   COMMAND_SCRIPT    =>    undef,
	   DO_FORK           =>    1,
	   NO_RUN            =>    0,
	   REDIRECT_OUTPUT   =>    1,
           REDIRECT_COMMAND  =>    ">%a.out",
	   ENV               =>    [],
	   DEBUG_USER_SCRIPT =>    0,
	   DEBUG_ENTIRE_SCRIPT=>   0,
	   DEFAULT_COMMAND   =>    "default",
	   NOTIFICATION      =>    "none",
	   
	   # Binaries
	   RSH               =>    "rsh",
	   SH                =>    "/bin/sh",
	   SH_OPTS           =>    "-s",

	   # Environment variables
	   ENV               =>    undef,
);

# Architectures to build for
@ARCHES = ();

# Specific architecture hosts
%HOSTS = ();

# Specific architecture environment
%ARCH_ENV = {};

# Commands to be run
@COMMANDS = ();

######################################################################
#
# Parse Commandline arguments
#

$PARSE_ERROR = 0;

# Set all these to avoid -w warnings
$opt_A = $opt_B = $opt_c = $opt_C = $opt_D = $opt_e = $opt_E = $opt_h = $opt_l = $opt_n = $opt_P = $opt_S = $opt_w = $opt_v = $opt_x = $opt_X = undef;

getopts('A:B:c:C:DeE:hlnP:Sw:vxX');

if ($opt_h) {
  Usage();
  exit 0;
}

if ($opt_v) {
  print "Buildall version $VERSION\n";
  exit 0;
}

$CONFIG{"LOCAL_CONF_FILE"} = $opt_c
  if $opt_c;

$CONFIG{"BUILDALL_DIR"} = $opt_B
  if $opt_B;

if ($opt_e || $opt_E) {
    # Import the sendmail module only if we need it
    eval("use Mail::Sendmail");
    die $@ if $@;

    $CONFIG{"NOTIFICATION"} = "email";
    my $USERNAME = getlogin || getpwuid($<);
    $USERNAME = $opt_E if $opt_E;

    # Check for a domain/host, Mail::Sendmail needs a fully qualified address
    $USERNAME .= "@" . hostname unless $USERNAME =~ /\@/;

    die "Could not determine username for email address" unless $USERNAME;

    $CONFIG{"NOTIFY_EMAIL"} = $USERNAME;

    print "Will send notification to " . $CONFIG{"NOTIFY_EMAIL"} . "\n";
}
    
$CONFIG{"LOCAL_CONF_FILE"} = $CONFIG{"BUILDALL_DIR"} . "/" . $opt_P . ".conf"
  if $opt_P;

if ($opt_P && $opt_c) {
  print STDERR "Cannot specify both '-c' and '-P'\n";
  $PARSE_ERROR = 1;
}

$CONFIG{"DUMP"} = $opt_D;

if ($opt_n) {
  $CONFIG{"NO_RUN"} = 1;
  print "Buildall not actually executing commands.\n";
}

$CONFIG{"DO_FORK"} = 0 if $opt_S;

$CONFIG{"DEBUG_USER_SCRIPT"} = $opt_x;

$CONFIG{"DEBUG_ENTIRE_SCRIPT"} = $opt_X;

exit(1)
  if ($PARSE_ERROR);

# Read out configuration file before processing other options
# so that they will override values in configuration file.
if (!ReadConfFiles()) {
  print STDERR "Error parsing configuration files. Exiting.\n";
  exit 1;
}

if ($opt_l) {
  ShowCommandList();
  exit(0);
}

if ($opt_A) {
  @ARCHES = split(/\s+/, $opt_A);
}

if ($opt_C) {
    print STDERR "-C option depreciated. Used commands of form !<cmd> instead.\n";
    $PARSE_ERROR = 1;
}

$CONFIG{"COMMAND_SCRIPT"} = $opt_C
  if $opt_C;

$CONFIG{"WORKING_DIR"} = $opt_w
  if $opt_w;

# Read any options specified on the command line
while ($ARGV[0] =~ /[^=\s]+=[^=\s]+/) {
  $CONFIG{"ENV"} .= " " if defined($CONFIG{"ENV"});
  $CONFIG{"ENV"} .= shift;
}

# Any remaining arguments are commands to be run
if ($#ARGV != -1) {
  @COMMANDS = @ARGV;

} else {
  @COMMANDS = ( $CONFIG{"DEFAULT_COMMAND"} );
}

exit(1)
  if ($PARSE_ERROR);

if (!MakeCommandScript()) {
  exit 1;
}

######################################################################
#
# Main Code
#

if ($#ARCHES == -1) {
  # No architectures specified on commandline check environement
  if (defined($ENV{"BUILDALL_ARCHES"})) {
    # Use architectures listed in environment variable
    @ARCHES = split(/[, ]/, $ENV{"BUILDALL_ARCHES"});

  } else {
    # Us all architectures that we know about
    @ARCHES = keys(%HOSTS);
  }
}

if ($#ARCHES == -1) {
    print STDERR "No architectures specified on commandline or host file\n";
    exit 0;
}

if ($CONFIG{"DUMP"}) {
    DumpConfig();
    exit 0;
}

# Unbuffer out output
$| = 1;

if ($CONFIG{"DO_FORK"}) {
    ParallelBuild();
} else {
    SerialBuild();
}
	
exit 0;

#
# End of main code
#
######################################################################

######################################################################
#
# Subroutines
#

######################################################################
#
# ParallelBuild
#
# Start all the builds in parallel
#
# Arguments: None
# Returns: Nothing
#

sub ParallelBuild {
    
    # Allow SIGHUP to restart hosts that finished with errors
    $SIG{HUP} = \&ParallelBuildRestart;

    print "Buildall building (pid is $$):";


    # Do it
  arch: foreach $ARCH (@ARCHES) {
	my $HOST = $HOSTS{$ARCH};

	# Check architecture and make sure we know how to build it
	# This is in case it was specified on the command line
	if (!defined($HOST)) {
	    print STDERR "Don't know how to build for $ARCH\n";
	    next arch;
	}

	print " $ARCH ($HOST)";

	my $PID = StartBackgroundBuild($HOST, $ARCH);
	    
	$PIDS{$PID} = $ARCH;

    }
	       
    print "\n";

  waitloop: while(($PID = wait) != -1) {
	$ARCH = $PIDS{$PID};
	$STATUS = $?;

	if (!defined($ARCH)) {
	    print STDERR "Caught unknown child (pid = $PID)\n";
	    next waitloop;
	}

	print "buildall on " . $HOSTS{$ARCH} . " for $ARCH finished";

	if ($STATUS) {
	    print " with ERRORS";
	    push(@FINISHED_WITH_ERRORS, $ARCH);
	}
	print "\n";

	Notify($ARCH, $STATUS);
    }
}



######################################################################
#
# SerialBuild
#
# Do all the builds in serial
#
# Arguments: None
# Returns: Nothing
#

sub SerialBuild {
    # Allow SIGHUP to restart hosts that finished with errors
    $SIG{HUP} = \&SerialBuildRestart;

    print "Buildall building (pid is $$):\n";

    do {
	# May be set by SerialBuildRestart()
	$SERIAL_RESTART_FLAG = 0;

      arch: foreach $ARCH (@ARCHES) {
	    my $HOST = $HOSTS{$ARCH};

	    # Check architecture and make sure we know how to build it
	    # This is in case it was specified on the command line
	    if (!defined($HOST)) {
		print STDERR "Don't know how to build for $ARCH\n";
		next arch;
	    }

	    print " $ARCH ($HOST)";

	    my $RC = DoHost($HOST, $ARCH);
	    
	    print " build finished";
	    print " with ERRORS" unless ($RC);
	    print "\n";

	    push(@FINISHED_WITH_ERRORS, $ARCH) unless ($RC);

	    Notify($ARCH, $STATUS);
	}

	if ($SERIAL_RESTART_FLAG) {
	    @ARCHES = @FINISHED_WITH_ERRORS;
	    @FINISHED_WITH_ERRORS = ();
	    print "Buildall restarting failed builds:\n";
	}

    } while ($SERIAL_RESTART_FLAG);
}



######################################################################
#
# StartBackgroundBuild
#
# Start up a host build in the background
#
# Arguments: Host name, architecture
# Returns: PID
#

sub StartBackgroundBuild {
  my $HOST = shift;
  my $ARCH = shift;

  my $PID = fork();

  # die on error
  die "fork failed: $!" unless defined($PID);

  # Return PID if we are the parent;
  return $PID if ($PID);

  # Child process
  my $RC = DoHost($HOST, $ARCH);

  exit($RC == 0);
}

  

######################################################################
#
# DoHost
#
# Handle a particular host.
#
# Arguments: Host name, architecture
# Returns: 1 on success, 0 on failure

sub DoHost {
  my $HOST = shift;
  my $ARCH = shift;


  if ($CONFIG{"REDIRECT_OUTPUT"}) {
    my $OUTPUT = ParseRedirect($HOST, $ARCH,
			       $CONFIG{"REDIRECT_COMMAND"});

    open(SAVE_STDOUT, ">&STDOUT") ||
      die "Could not duplicate STDOUT: $!";
  
    open(SAVE_STDERR, ">&STDERR") ||
      die "Could not duplicate STDERR: $!";

    if (!open(STDOUT, $OUTPUT)) {
      print STDERR "Could not redirect stdout to \"$OUTPUT\": $!\n";
      exit 1;
    }

    if (!open(STDERR, ">&STDOUT")) {
      print STDERR "Could not redirect stderr: $!\n";
      exit 1;
    }

    # Turn off buffering
    $| = 1;
  }

  my $PRECOMMAND_SCRIPT = undef;
  my $COMMAND_SCRIPT = $CONFIG{"COMMAND_SCRIPT"};
  my $POSTCOMMAND_SCRIPT = undef;

  $PRECOMMAND_SCRIPT .= "set -x\n" if $CONFIG{"DEBUG_ENTIRE_SCRIPT"};
  
  # Prepend code to check architrecutre
  $PRECOMMAND_SCRIPT .= CheckHostArchCode($HOST, $ARCH);

  # Prepend code to set up environment variables
  $PRECOMMAND_SCRIPT .= EnvSetupCode($HOST, $ARCH);

  # Prepend options code
  $PRECOMMAND_SCRIPT .= EnvCode($CONFIG{"ENV"});
  $PRECOMMAND_SCRIPT .= EnvCode($ARCH_ENV{$ARCH});

  # Prepend code to cd to working directory
  if (defined($CONFIG{"WORKING_DIR"})) {
    $PRECOMMAND_SCRIPT .= WorkingDirCode($CONFIG{"WORKING_DIR"});
  }

  # Other shell options
  $PRECOMMAND_SCRIPT .= "set -x\n" if $CONFIG{"DEBUG_USER_SCRIPT"};

  # Send the return status back through stdout so we can pick it up
  $POSTCOMMAND_SCRIPT .= "
echo BUILDALL EXIT STATUS \$?
";

  # Set up pipe for talking to rsh's stdin
  if (!pipe(FROM_PARENT, TO_RSH)) {
    print STDERR "Could not set up pipe to rsh: $!\n";
    return 0;
  }

  # Spawn child to exec rsh
  my $PID = fork();

  if ($PID == 0) {
    # Child

    close(TO_RSH);
    
    if (!open(STDIN, "<&FROM_PARENT")) {
      print STDERR "Could not redirect stdin: $!";
      exit 1;
    }
    
    close(FROM_PARENT);

    my $RSH_CMD = sprintf("%s %s \"%s %s\"|", $CONFIG{"RSH"}, $HOST,
			  $CONFIG{"SH"}, $CONFIG{"SH_OPTS"});

    if ($CONFIG{"NO_RUN"}) {
      print "** Buildall in no run mode **\n";
      print "** Rsh command: $RSH_CMD\n";
      $RSH_CMD = "cat |";
    }

    if (!open(FROM_RSH, $RSH_CMD)) {
      printf(STDERR "Could not exec rsh (%s): $!", $CONFIG{"RSH"});
      exit 1;
    }

    # Return error by default
    my $STATUS = 1;
      
    while(<FROM_RSH>) {

      # Scan for exit status, parse and remove
      if (/BUILDALL EXIT STATUS (\d+)/) {
	$STATUS = $1;
	next;
      }

      print;
    }
	
    close(FROM_RSH);

    # Don't return error if in NO_RUN mode
    $STATUS = 0 if $CONFIG{"NO_RUN"};
    
    exit($STATUS);
  }

  # Send the command to rsh and on to the other side
  # The precommand and command go in a subshell and then
  # postcommand is run afterwards.
  print TO_RSH "(\n";
  print TO_RSH $PRECOMMAND_SCRIPT . "\n";
  print TO_RSH $COMMAND_SCRIPT . "\n";
  print TO_RSH ")\n";
  print TO_RSH $POSTCOMMAND_SCRIPT . "\n";
  close(TO_RSH);
  
  if (wait == -1) {
    print STDERR "wait failed: $!\n";
    return 0;
  }

  if ($CONFIG{"REDIRECT_OUTPUT"}) {
    # Restore STDOUT and STDERR
    open(STDOUT, ">&SAVE_STDOUT") ||
      die "Could not restore STDOUT: $!";
  
    open(STDERR, ">&SAVE_STDERR") ||
      die "Could not duplicate STDERR: $!";
  }

  
  my $STATUS = $? >> 8;
  
  return 0 if ($STATUS);
  
  # Success
  return 1;
}



######################################################################
#
# ParallelBuildRestart
#
# Restart all the architectures that finished with errors.
#
# Arguments: None
# Returns: Nothing
#

sub ParallelBuildRestart {
  my $ARCH;

  print "Buildall restarting builds:";

  while($ARCH = shift(@FINISHED_WITH_ERRORS)) {

    print " $ARCH (" . $HOSTS{$ARCH} . ")";

    my $PID = StartBackgroundBuild($HOSTS{$ARCH}, $ARCH);

    $PIDS{$PID} = $ARCH;
  }

  print "\n";
}



######################################################################
#
# SerialBuildRestart
#
# Restart all the architectures that finished with errors.
#
# Arguments: None
# Returns: Nothing
#

sub SerialBuildRestart {
    $SERIAL_RESTART_FLAG = 1;
}



######################################################################
#
# CheckHostArchCode
#
# Return code to check the host's architecture and make sure it
# matches what is expected.
#
# Arguments: Host, Architecture
# Returns: Code

sub CheckHostArchCode {
  my $HOST = shift;
  my $ARCH = shift;

  my $CODE = "";

  my $OS_SED = "";
  my $VER_SED = "";
  my $IRIX_BITS_FLAG = undef;


  # Convert HP-UX to HPUX
  $OS_SED = "| sed -e \"s/HP-UX/HPUX/\"" if ($ARCH =~ /HPUX/);
  
  # Convert IRIX64 to IRIX
  $OS_SED = "| sed -e \"s/IRIX64/IRIX/\"" if ($ARCH =~ /IRIX/);

  # Get any IRIX -32/-n32/-64 flag specified
  if ($ARCH =~ /IRIX.*(-n?\d+)/) {
    $IRIX_BITS_FLAG = $1;
  }

  # Convert B.10.20 to 10.20 for HPUX
  $VER_SED = "| sed -e \"s/B\.//" if ($ARCH =~ /HPUX/);

    
  $CODE = "
BA_REAL_OS=`uname -s $OS_SED`
BA_REAL_VER=`uname -r $VER_SED`
BA_REAL_ARCH=\$BA_REAL_OS\"_\"\$BA_REAL_VER\
";

  if (defined($IRIX_BITS_FLAG)) {
    # Append IRIX_BITS_FLAG to make architecture match
    $CODE .= "
BA_IRIX_BITS_FLAG=$IRIX_BITS_FLAG
BA_REAL_ARCH=\$BA_REAL_ARCH\$BA_IRIX_BITS_FLAG
";
  }

  if ($ARCH =~ /linux-x86-(.?libc\d?)/) {
    # If this is linux then we need to check if it's libc or glibc
    # And if it's glibc what major version it is
    my $LIBC = $1;

    $CODE .= "
if [ \$BA_REAL_OS != Linux ]; then
  echo \"Architecture on $HOST (\$BA_REAL_ARCH) does not match desired ($ARCH)\"
  echo BUILDALL EXIT STATUS 1
  exit 1
fi

# Use sed to remove everything after first dash
BA_LIBC_RPM_OUTPUT=`rpm -q -f /usr/lib/libc.a`
BA_LIBC_TYPE=`echo \$BA_LIBC_RPM_OUTPUT | cut -d - -f 1`
BA_LIBC_VERSION=`echo \$BA_LIBC_RPM_OUTPUT | cut -d - -f 3`
BA_LIBC_MAJOR_VERSION=`echo \$BA_LIBC_VERSION | cut -d . -f 1`

if [ \$BA_LIBC_TYPE = \"glibc\" -a \$BA_LIBC_MAJOR_VERSION != 1 ]; then
  # Append major version number if > 1
  BA_LIBC_TYPE=\${BA_LIBC_TYPE}\${BA_LIBC_MAJOR_VERSION}
fi

if [ \$BA_LIBC_TYPE != $LIBC ]; then
  echo \"libc on $HOST (\$BA_LIBC_TYPE) does not match desired ($LIBC)\"
  echo BUILDALL EXIT STATUS 1
  exit 1
fi
";
  } else {
    # Non-Linux code
    $CODE .="
if [ \$BA_REAL_ARCH != $ARCH ]; then
  echo \"Architecture on $HOST (\$BA_REAL_ARCH) does not match desired ($ARCH)\"
  echo BUILDALL EXIT STATUS 1
  exit 1
fi
";
  }

  return $CODE;
}


######################################################################
#
# MakeCommandScript
#
# Fill in $CONFIG{"COMMAND_SCRIPT"} with script to be run
#
# Arguments: None
# Returns: 1 on success, 0 on error
#

sub MakeCommandScript {
  
  my $ERROR = 0;
  my $COMMAND_SCRIPT;

    
  # Build command script from given commands
  if ($#COMMANDS == -1) {
    print STDERR "No commands given\n";
    return 0;
  }
    
  # Run each command in a subshell if there are more than one
  my $USE_SUBSHELLS = ($#COMMANDS > 0) ? 1 : 0;

 COMMAND: foreach $CMD (@COMMANDS) {
    $COMMAND_SCRIPT .= "(\n" if $USE_SUBSHELLS;

    if ($CMD =~ /^@(.*)/) {
      # Read command from file
      my $CMD_SCRIPT = ReadCommandFile($1);

      if (!defined($CMD_SCRIPT)) {
	print STDERR "Could not open command file \"$FILE\": $!\n";
	$ERROR = 1;
	next COMMAND;
      }

      $COMMAND_SCRIPT .= $CMD_SCRIPT;
	
    } elsif ($CMD =~ /\!(.*)/) {
      # Literal command
      my $CMD_SCRIPT = $1;

      if (!defined($CMD_SCRIPT)) {
	print STDERR "Could not parse command \"$CMD\"\n";
	$ERROR = 1;
	next COMMAND;
      }

      $COMMAND_SCRIPT .= $CMD_SCRIPT;

    } else {
      # Use command from configuration files
      if (!defined($COMMAND{$CMD})) {
	print STDERR "Unknown command \"$CMD\"\n";
	$ERROR =1;
	next COMMAND;
      }
      
      $COMMAND_SCRIPT .= $COMMAND{$CMD} . "\n";
    }

    $COMMAND_SCRIPT .= ") || exit \$?\n" if $USE_SUBSHELLS;
  }

  # If BA_PRE and BA_POST commands are defined then prepend/append
  # then to the command script
  $COMMAND_SCRIPT = $COMMAND{"BA_PRE"} . "\n" . $COMMAND_SCRIPT
    if (defined($COMMAND{"BA_PRE"}));
  
  $COMMAND_SCRIPT .= "\n" . $COMMAND{"BA_POST"} . "\n"
    if defined($COMMAND{"BA_POST"});

  $CONFIG{"COMMAND_SCRIPT"} = $COMMAND_SCRIPT;

  return ($ERROR ? 0 : 1);
}
    


######################################################################
#
# Notify
#
# Notify the user that a build has finished.
#
# Arguments: Architecture, Status
# Returns: Nothin
#

sub Notify {
    my $ARCH = shift;
    my $STATUS = shift;

    if ($CONFIG{"NOTIFICATION"} eq "none") {
	# Nothing to do

    } elsif ($CONFIG{"NOTIFICATION"} eq "email") {
	my %MAIL = ();

	$MAIL{"To"} = $CONFIG{"NOTIFY_EMAIL"};

	$MAIL{"From"} = "buildall@" . hostname;

	$MAIL{"Subject"} = "BUILDALL: $ARCH (" . $HOSTS{$ARCH} . ") finished";
	$MAIL{"Subject"} .= " with ERRORS" if $STATUS;
	
	$MAIL{"Message"} = $MAIL{"Subject"};

	sendmail(%MAIL) ||
	  die "Mail error sending to " . $MAIL{"To"} .
	    ": " . $Mail::Sendmail::error;
	
    } else {
	print STDERR "Unknown notification method \"" .
	  $CONFIG{"NOTIFICATION"} . "\"\n";
    }
}

    

######################################################################
#
# WorkingDirCode
#
# Return code for changing to the given working directory.
#
# Arguments: Working dir
# Returns: Code

sub WorkingDirCode {
  my $WDIR = shift;

  my $CODE = "
if [ ! -d $WDIR ]; then
  # Try with and without -p
  mkdir -p $WDIR || mkdir $WDIR
fi
cd $WDIR || exit 1
";

  return $CODE;
}


######################################################################
#
# EnvSetupCode
#
# Return code for setting up the command script's environment
#
# Argumnets: Host, Architecture
# Returns: Code

sub EnvSetupCode {
  my $HOST = shift;
  my $ARCH = shift;

  my $CODE = undef;

  $CODE .= "BA_ARCH=$ARCH ; export BA_ARCH\n";
  $CODE .= "BA_HOST=$HOST ; export BA_HOST\n";

  return $CODE;
}


######################################################################
#
# EnvCode
#
# Given a reference to an array of environment variables, generate
# code to set all of them.
#
# Arguments: Environment String
# Returns: Code

sub EnvCode {
  my $ENV_ARRAY_REF = shift;

  return ""
    if !defined($ENV_ARRAY_REF);

  my $CODE = "";

  foreach $ENV_STRING ( @$ENV_ARRAY_REF ) {
    if ($ENV_STRING =~ /([^=]+)=([^=]+)/) {
      my $VARIABLE = $1;
      my $VALUE = $2;

      $CODE .= "$VARIABLE=$VALUE ; export $VARIABLE\n";
    } else {
      print STDERR "Bad environment string \"$ENV_STRING\"\n";
    }
  }

  return $CODE;
}


######################################################################
#
# ExecCommand
#
# Execute a command returning it's exit status.
#
# Argument: Command
# Returns: Exit status

sub ExecCommand {
    my $COMMAND = shift;

    printf("Executing command %s\n", $COMMAND);

    if ($CONFIG{"NO_RUN"}) {
      return 0;
    }

    my $RC = system($COMMAND);

    return ($RC / 256);
}



######################################################################
#
# Usage
#
# Print usage information
#
# XXX Update me
#
# Arguments: None
# Returns: Nothing

sub Usage {
    print "
Usage: $0 [<options>] [<environment variables>] [<commands>]

Options are:
  -A <arches>         Specify architectures to build for.
  -B <buildall dir>   Specify location of global buildall directory
                      Default is \$HOME/.buildall
  -c <conf file>      Specify local configuration file to use
                      Default is ./buildall.conf
  -D                  Dump Configuration and exit.
  -e                  Notify via email as each build completes.
  -E <address>        Specify email address to send notification to.
  -h                  Print usage and exit.
  -l                  Print list of configured commands and exit.
  -n                  Print commands but don't actually run them.
  -P <project>        Use <buildall dir>/<project>.<conf> in place
                      of local configuration file.
  -S                  Do builds in serial instead of parallel.
  -w <dir>            Specify working directory.
  -v                  Print version and exit.
  -x                  Print user script commands before execution.
  -X                  Print all script commands before execution.

Environment variables are string of the form: VARIABLE=VALUE

For more details see the man page which can be viewed by running:

perldoc $0

";
}


######################################################################
#
# FindConfFile
#
# Find the local configuration file and return it's path.
#
# Arguments: None
# Returns: Path

sub FindConfFile {

  return $ENV{"BUILDALL_CONF"} || "./buildall.conf";
}


######################################################################
#
# FindBuildallDir
#
# Return the path to the global buildall directory.
#
# Arguments: None
# Returns: Path

sub FindBuildallDir {
  my $BUILDALL_DIR = undef;

  if (defined($ENV{"BUILDALL_DIR"})) {
    $BUILDALL_DIR = $ENV{"BUILDALL_DIR"};

  } elsif (defined($ENV{"HOME"})) {
    
    $BUILDALL_DIR = $ENV{"HOME"} . "/.buildall";

  } else {
    
    $BUILDALL_DIR = undef;

  }

  return $BUILDALL_DIR;
}

      
  
######################################################################
#
# ReadConfFiles
#
# Read the config files, putting the results into %CONFIG.
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub ReadConfFiles {
  my $STATUS = 1;
  # Order is important here as later config files override
  # previous ones.

  if (defined($CONFIG{"BUILDALL_DIR"}) &&
      ($CONFIG{"BUILDALL_DIR"} ne "-")) {
    ReadConfFile($CONFIG{"BUILDALL_DIR"} . "/buildall.conf") ||
      ($STATUS = 0);
  }

  if (defined($CONFIG{"LOCAL_CONF_FILE"}) &&
      ($CONFIG{"LOCAL_CONF_FILE"} ne "-")) {
    ReadConfFile($CONFIG{"LOCAL_CONF_FILE"}) ||
      ($STATUS = 0);
  }

  return $STATUS;
}

######################################################################
#
# ReadConfFile
#
# Read the given config file, putting the results into %CONFIG.
# On error prints and error and dies.
#
# Arguments: None
# Returns: 1 on success, 0 on error

sub ReadConfFile {
    my $FILE = shift;
    my $STATUS = 1;

    return
      if !defined($FILE);

    if (!open(FILE, $FILE)) {
	print STDERR "Could not open config file \"$FILE\": $!\n";
	return 0;
    }

  line: while (<FILE>) {
	my $CONF;

	# Remove comments
	s/\#[^\n]*\n/\n/g;

	# Remove CR if present
	s/\n$//;

	# Ignore blank lines
	next line
	  if /^\s*$/;

	# Split off first token
	($CONF, $_) = split(/\s+/, $_, 2);

	# Make $CONF uppercase
	$CONF =~ y/[a-z]/[A-Z]/;

	if ($CONF eq "ARCH") {
	    # Architecture, host and options
	    my ($ARCH, $HOST, $ENV) = split(/\s+/, $_, 3);

	    if (!defined($ARCH) || !defined($HOST)) {
		print STDERR "Bad ARCH option on line $. of $FILE\n";
		$STATUS = 0;
		next line;
	    }

	    $HOSTS{$ARCH} = $HOST;
	    $ARCH_ENV{$ARCH} = $ENV;

	} elsif ($CONF eq "TARGETS") {

	  @ARCHES = split(/\s+/, $_);
	  
	} elsif ($CONF eq "ARCH_ENV") {
	  
	  my ($ARCH, $ENV_STRING) = split(/\s+/, $_, 2);

	  if (!defined($ARCH)) {
	    print STDERR "Bad ARCH_ENV option on line $. of $FILE\n";
	    $STATUS = 0;
	    next line;
	  }

	  if (!defined($HOSTS{$ARCH})) {
	    print STDERR "Unknown architecture \"$ARCH\" on line $. of $FILE\n";
	    $STATUS = 0;
	    next line;
	  }

	  if ($ENV_STRING !~ /([^=]+)=([^=]+)/) {
	    print STDERR "Bad environment variable format on line $. of $FILE\n";
	    $STATUS = 0;
	    next line;
	  }

	  if (!defined($ARCH_ENV{$ARCH})) {
	    $ARCH_ENV{$ARCH} = [ ];
	  }
	    
	  push(@{$ARCH_ENV{$ARCH}}, $ENV_STRING);

	} elsif ($CONF eq "COMMAND") {
 	  my $NAME;

	  # Get command name
	  ($NAME, $_) = split(/\s+/, $_, 2);
	  
	  $NAME = $NAME || "default";

	  # Override any previous command
	  $COMMAND{$NAME} = undef;

	  while(<FILE>) {
	    last
	      if (/COMMAND_END/);

	    $COMMAND{$NAME} .= $_;
	  }
	} elsif ($CONF eq "ENV") {
	  my $ENV_STRING = $_;

	  if ($ENV_STRING =~ /([^=]+)=([^=]+)/) {
	    push(@{$CONFIG{"ENV"}}, $ENV_STRING);

	  } else {
	    print STDERR "Bad environment variable format on line $. of $FILE\n";
	    $STATUS = 0;
	    next line;
	  }

	} else {
	    # Generic configuration parameter
	    my $VALUE = $_;

	    if (!exists($CONFIG{$CONF})) {
	      print STDERR "Unknown option \"$CONF\" on line $. of $FILE\n";
	      $STATUS = 0;
	      next line;
	    }

	    $CONFIG{$CONF} = $VALUE;

	}
    }

    close(FILE);

    return $STATUS;
}



######################################################################
#
# ReadCommandFile
#
# Read $CONFIG{"COMMAND"} from the given file.
#
# Argumets: Command file name
# Returns: contents of file or undef on error

sub ReadCommandFile {
  my $FILE = shift;
  my $COMMAND = undef;

  open(FILE, $FILE) || return 0;

  while (<FILE>) {
    $COMMAND .= $_;
  }

  close(FILE);

  return $COMMAND;
}



######################################################################
#
# ShowCommandList
#
# Show a list of available commands.
#
# Arguments: None
# Returns: Nothing

sub ShowCommandList {
  my @CMDS = keys(%COMMAND);
  my $COLUMN = 0;
  my $MAX_COLUMN = 78;

  print "Available commands:\n";

  foreach $CMD (@CMDS) {
    # Skip special commands
    next if (($CMD eq "BA_PRE") ||
	     ($CMD eq "BA_POST"));

    # plus 1 for space
    if (($COLUMN + length($CMD) + 1) > $MAX_COLUMN) {
      print "\n";
      $COLUMN = 0;
    } else {
      print " ";
    }

    print $CMD;

    $COLUMN += length($CMD);
  }

  print "\n\n";
}


      
######################################################################
#
# DumpConfig
#
# Dump configuration.
#
# Arguments: None
# Returns: Nothing

sub DumpConfig {

  if (defined($CONFIG{"COMMAND_SCRIPT"})) {
    print "Command script to be run is:\n\n";
    print $CONFIG{"COMMAND_SCRIPT"} . "\n\n";

  }

  my $ENV_ARRAY = $CONFIG{"ENV"};
  print "Environment is : " . join(',', @$ENV_ARRAY) . "\n\n";

  foreach $ARCH (@ARCHES) {
    if (!defined($HOSTS{$ARCH})) {
      print "Unrecognized architecture \"$ARCH\"\n";
      next;
    }

    print "Host for $ARCH is " . $HOSTS{$ARCH};

    my $ARCH_ENV_ARRAY = $ARCH_ENV{$ARCH};
    if (defined($ARCH_ENV_ARRAY)) {
      print " env variables are " . join(',', @$ARCH_ENV_ARRAY);
    }

    print "\n";
  }
}

######################################################################
#
# ParseRedirect
#
# Parse a command substitution the following values:
#    %h       Host the build is being done on
#    %a       Architecture build is for
#
# Arguments: Host, Architecture, redirection command
# Returns: Parsed string

sub ParseRedirect {
  my $HOST = shift;
  my $ARCH = shift;
  my $COMMAND = shift;

  $COMMAND =~ s/%h/$HOST/;
  $COMMAND =~ s/%a/$ARCH/;

  return $COMMAND;
}



__END__

######################################################################
#
# POD documentation

=head1 NAME

buildall - run a command on multiple machines.

=head1 SYNOPSIS

buildall [<options>] [<environment variables>] [<commands>]

buildall is a script that was written to allow building a software
package on multiple architectures simultaneously. It uses rsh (or
comporable command) to execute a given command script on a number of
machines, saves the output, and reports on each machines success
or failure.

=head1 DESCRIPTION

buildall starts by reading reading a list of configuration options
from a global configuration file, F<~/.buildall/buildall.conf> by default
but this can be overridden with the I<BUILDALL_DIR> environment variable
and the B<-B> command line option.

After reading the global configuration file it reads the local configuration
file, which in general is specific to each package being built.
By default this is the file F<./buildall.conf>, but this can be overridden
with the I<BUILDALL_CONF> environment variable and the B<-c> command line
option. This file contains specific commands that can be run as well as
other package-specific options. Values in this local file override any
set in the global configuration file. See L<CONFIGURATION FILE> for details.

Build then runs the specified commands as given on the command line (or
'default' if none was given) simultaneously on all hosts specified.
It saves the output from each host and prints a failure/success message as
determined by the return code from the command. Each command is run
starting from the given working directory. If any command returns non-zero
buildall does not run any further commands.

If a command begins with an exclamation mark (C<!>) then the rest of the
string is taken to be a literal piece of shell code to be executed.
Note that because of shell substitution it is normally necessary to precede
the exclamation mark with a backslash (\). 

If a command begins with an at sign (C<@>) then the rest of the string is
taken to be the name of a file to read and use as the command text. The
string C<@-> cause buildall to read the command script from stdin. Having
more that one C<@-> command won't work.

=head1 COMMANDLINE ARGUMENTS

buildall accepts the following options:

=over 4

=item -A I<arches>

Specuify which architectures to build for. Note that if you give more than
one you will need to quote the list - e.g. B<-A> "IRIX_6.3 IRIX_6.4"

=item -b I<configuration file>

Specify a build file to use instead of F<./buildall.conf>

=item -B I<buildall directory>

Specify location of global buildall directory instead of
F<$HOME/.buildall>

=item -D

Dump configuration after parsing and exit.

=item -e

Send email as each architecture's build completes. By default email
will be sent to the account of the user running buildall. See also
B<-E>.

=item -E I<address>

Specify an email address to send email notification to. B<-e> is assumed
if B<-E> is given. See B<-e>.

=item -h

Print usage and exit.

=item -l

Print list of configured commands and exit.

=item -n

Don't actually run any commands, just print the command script as would
be run.

=item -P I<project>

Use F<BUILDALL DIRECTORY/PROJECT.conf> in place of the local configuration
file. For example I<-P test> would cause buildall to use
F<$HOME/.buildall/test.conf> instead of F<./buildall.conf>.

=item -S

Causes the builds to be done in serial instread of in parallel.

=item -w I<working dir>

Specify the directory that the scripts are to be run in. See the
I<WORKING_DIR> option in L<BUILD FILE>.

=item -v

Print Buildall's version and exit.

=item -x

Run shell with C<-x> flag on remote systems. Note that because of buffering
that the commands and their outputs may get out of order.

=back

Following the options environment variables maybe be specified. These
are strings of the form C<variable=value>. These variables will be
set for the command scripts.

The final option on the command line should be the name of the command
to execute. If none is given the default command is executed.

=head1 CONFIGURATION FILE

The global and local configuration files specify the available
architecures, hosts, and commands to be run. Any options in the
local configuration file override those in the global configuration
file. This allows you to have a global file full of defaults, but
override them with the local configuration file.

The following lines are allowed in the configuration files:

=over 4

=item ARCH <architecture> <hostname> [<options>]

Specify a architecure, the host used to build for that architecture,
and, optionally, environment variables to be set on that host.
Enviroment variables should be of the form C<variable=value>.
See L<"ARCHITECTURE NAMES"> for a description of what
the architecture name should be.

=item ARCH_ENV <architecture> <env settings>

Specify environment variables to be set in the command script for a
specific architecture. These settings will override any general settings
and any given in the architecture file.

=item COMMAND [<command name>]

Specify a command script that can be run on the remote systems. C<command>
is the name of this command and can be specified on buildall's command line.
If no name is given this, it will be assigned the name "C<default>" which
by default is the default command run. The command
script itself should start on the next line and should be a bourne shell
script. It should be terminated with the text COMMAND_END on a line by
itself. See L<COMMAND SCRIPT> for more details.

=item DEFAULT_COMMAND <command name>

Specify the command script to be run as the default. Normally it is the
command named as "C<default>".

=item ENV <env settings>

Specify environment variables to be set in the command script. The settings
should be one or more strings of the form C<variable=value>. These settings
will be overridden by any given on the command line or that are architecture
specific.

=item REDIRECT_COMMAND <command>

Specify a command to use for redirection of the output from the commands.
This should start with '>' (for a file) or '|' (for a program). See 
L<REDIRECT COMMAND> for more details.

=item RSH <program>

Specify a program to use in place of F<rsh>, which is the default.

=item TARGETS [<arches>]

Specify a subset of the architectures given to actually build for.

=item WORKING_DIR <path>

Specify the directory to run in on the remote hosts. C<Path> may use
any of the variables available to command scripts. See L<COMMAND
SCRIPT> for details.

=item # <comment>

The pound character (C<#>) indicates a comment. Any text from the pound
character to end of line is discarded.
options to replace the I<%o> string in the command run on that host.

=back

=head1 CONFIGURATION FILE EXAMPLES

Here is an example of what the global configuration file might look like.
It specifies machines for Solaris 2.5, IRIX 6.5 and a Linux machine with
glibc. On the IRIX machine the variable C<CC> will be set to C<cc>.

  #
  # Example buildall.arch (this is a comment)
  #

  ARCH SunOS_5.5 mecury
  ARCH IRIX_6.5 venus CC=cc
  ARCH linux_x86_glibc earth

Here is an example of what a local configuration file might look like.

  #
  # Example build file for buildall (this is a comment)
  # This file would normally be ./buildall.conf
  #

  # Our working directory on the target machines is
  # /afs/ncsa/scratch/<architecture name>
  WORKING_DIR /afs/ncsa/scratch/$BA_ARCH

  # Set some environment variables
  ENV CC=gcc

  # Set an environment variable specifically for IRIX
  ARCH_ENV IRIX_6.5 CC_OPTS=-32

  # Build only for IRIX 6.5 and Linux
  TARGETS IRIX_6.5 linux_x86_glibc

  # Default command, this is what gets run when we just type 'buildall'
  COMMAND
  make
  COMMAND_END

  # Allow us to type 'buildall clean'
  COMMAND clean
  make clean
  COMMAND_END

  # A more complicated test command. The return code from diff
  # will be used to determine success or failure.
  COMMAND test
  myprog > myprog.out
  diff myprog.out expected.out
  COMMAND_END

  # The BA_PRE and BA_POST are special commands that are always run
  # before/after any command. We'll use them here to print messages
  COMMAND BA_PRE
  echo "Buildall start"
  COMMAND_END

  COMMAND BA_POST
  echo "Buildall finished"
  COMMAND_END


=head1 COMMAND SCRIPTS

Command scripts are bourne shell scripts, plain and simple. The return
value from the script is used to determine success or failure (zero is
success, nonzero is failure).

The following variables will be set for the script when it is run.

=over 4

=item BA_ARCH

This will be set to the architecure the script is running under.

=item BA_HOST

This will be set to the name of the host the script is running on.

=item BA_IRIX_BITS_FLAG

If the architecture name specifies an IRIX system and a -32/-n32/-64
suffix, then BA_IRIX_BITS_FLAG will contain that suffix.

=back

In addition any environment variables specified on the command line or
under the C<ARCH> directive for this architecture will be present.

The following special command script names are defined:

=over 4

=item BA_PRE

This command script will always be run prior to any command script run.

=item BA_POST

This command script will always be run after any command script run.

=back

=head1 ARCHITECTURE NAMES

Architectures names, in general, are the concatenation of
C<uname -s>, C<_>, and C<uname -r>. For example a IRIX 5.3 box would be
IRIX_5.3. Solaris boxes are known as SunOS, so a Solaris 2.4 box would
be SUNOS_5.4.

Exceptions to this rule are:

Under Linux where names are either 'linux_x86_libc' or 'linux_x86_glibc'.
The C<x86> refers to the processor type. The C<libc> or C<glibc> refer to
the type of libc.a running on the system.

Under IRIX architecture names may have a C<-32>, C<-n32> or C<-64>
suffix. These suffixes are ignored except for being set in the
BA_IRIX_BIT_FLAGS variable. The intention is to allow for multiples
builds with the different flags.

=head1 REDIRECT COMMAND

The redirect command is basically just a shell commands that you
would use for any output redirection. You only need to redirect
standard out which includes standard error. Basically this means
that the command should start with a '>' to redirect to a file
or a '|' to redirect to a program.

The following special strings are allowed and are replaced with
the following values at runtime:

=over 4

=item %a

This is replaced with the name of this architecture.

=item %h

This is replaced with the name of the target host for this architecture.

=back

The default redirect command is ">%a.out".

=head1 EXAMPLES

Just running C<buildall> runs the C<default> command on all specified
architectures.

The following command runs the C<clean> command followed by the default
command on all architectures:

C<buildall clean default>

The following runs the given shell commands on all architectures:

C<buildall "\!rm Makefile ; configure ; gmake">

The following runs the C<install> command only under IRIX 6.5:

C<buildall -A IRIX_6.5 install>

The following runs the shell script C<build.sh> under IRIX 6.5 and
SunOS 5.4:

C<buildall -A "IRIX_6.5 SunOS_5.4" @build.sh>

The following reads a command script from C<stdin> and runs it on
all architecures:

C<buildall @->

=head1 SIGNALS

buildall recognizes the following signals:

=over 4

=item SIGHUP

This causes buildall to rebuild any builds that returned with
errors. The assumption is that the user has corrected some problem
and wants buildall to try those architectures again.

=back

=head1 FILES

=over 4

=item ./buildall.conf

Default location for the local configuration file.

=item ~/.buildall/buildall.arch

Default location for the global configurationfile.

=back

=head1 ENVIRONMENT VARIABLES

=over 4

=item BUILDALL_ARCHES

If set this is taken as a list of space-delimted architectures to
build for, equivalent to the C<-A> command line option.

=item BUILDALL_DIR

If set indicates the path where the global configuration file is
looked for. i.e. $BUILDALL_DIR/buildall.conf. If set to C<-> then
no global configuration file is read.

=item BUILDALL_CONF

If set indicates the location of the local configuration file. 
If set to C<-> then no local configuration file is read.

=item HOME

Used to find the default location of the global configuration file.

=back

=head1 TODO

=over 4

=item *

Better signal handling.

=item *

Fix stderr and stdout output geing rearranged.

=item *

Add a way to specify a particular command as the default

=back

=head1 AUTHOR

Von Welch (vwelch@ncsa.uiuc.edu)

=cut
