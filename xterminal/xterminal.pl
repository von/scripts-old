#!/usr/bin/perl -w
######################################################################
#
# xterminal
#
# Spawn a xterm with a login to the given host.
#
# XXX If host options is empty for a host we get a weird error.
#
######################################################################
#
# GLOBALS
#

%Host_Options = ();

%Binaries = (
	     # Binaries
	     "rlogin"                  => "rlogin",
	     "rxvt"                    => "rxvt",
	     "ssh"                     => "ssh",
	     "telnet"                  => "telnet",
	     "xterm"                   => "xterm",
	    );

# General options
%Options = (
	    "debug"                   => 0,
	  );

%Connect_Options = (
		    # Conntection options
		    "connect_method"          => undef,
		    "cleartext"               => 0,
		    "remotehost"              => undef,

		    # user parameters
		    "remoteuser"              => undef,

		    # Port to connect to
		    "port"                    => undef,
		   );

%Xterm_Options = (
		  #
		  # xterm options
		  #
		  "program"                 => "xterm",
		  "geometry"                => undef,
		  "title"                   => undef,
		  "titlechange"             => 1,
		  "title_no_modify"         => 0,
		  "foreground"              => "white",
		  "background"              => "black",
		  "login_shell"             => 1,
		  "scrollbar"               => 1,
		  "utmp_entry"              => 0,
		  "inhibit_key_scroll"      => 1,
		  "inhibit_output_scroll"   => 1,
		  "tek_window"              => undef,
		  "visual_bell"             => 1,
		 );

######################################################################
#
# Strings we append to title
#

$Title_Local =                 "(Local)";
$Title_SSH =                   "(SSH)";
$Title_Krb5_Encrypt =          "(Krb5 Encrypted)";

######################################################################

read_config_file($ENV{HOME} . "/.xterminal/config");

use Getopt::Long;

my $arg_error = 0;

# Stop at first non-option
Getopt::Long::Configure("require_order");

GetOptions(
	   "--debug!"                   => \$Options{debug},
	   # Connection options
	   "--connect-method=s"         => \$Connect_Options{connect_method},
	   "--remote_user=s"            => \$Connect_Options{remoteuser},
	   # Xterm options
	   "--title=s"                  => \$Xterm_Options{title},
	   "--titlechange!"             => \$Xterm_Options{titlechange},
	   "--visual_bell!"             => \$Xterm_Options{visual_bell},
	   "--geometry=s"               => \$Xterm_Options{geometry},
	   "--program=s"                => \$Xterm_Options{program},
	  ) || ($arg_error = 1 );

my $target = shift;

if ($arg_error) {
  print STDERR "Error parsing commandline";
  # XXX Usage
  exit(1);
}

######################################################################
#
# Figure out our host and domain name

use Sys::Hostname;

my $fullhostname = hostname();
my $hostname = $fullhostname;
my $domainname = undef;

if ($fullhostname =~ /(\w+)\.([\w\.]+)/) {
  $hostname = $1;
  $domainname = $2;
}

# XXX May not know domainname

######################################################################
#
# Figure out if we are logging into local host
#

# For backwards compatability
if (!defined($target) ||
    ($target eq "local") ||
    ($target eq "localhost")) {

  $target = "localhost";
  $Connect_Options{connect_method} = "local";
}

if (($target eq $fullhostname) ||
    ($target eq $hostname)) {
  $Connect_Options{connect_method} = "local";
}

$Connect_Options{remotehost} = $target;

######################################################################
#
# Set the default title
#

if (defined($Xterm_Options{title})) {
  # If title is set by user then don't mess with it
  $Xterm_Options{title_no_modify} = 1;

} else {

  if ($target eq "localhost") {
    $Xterm_Options{title} = $hostname;
  } else {
    $Xterm_Options{title} = $target;
  }

  if (defined($Connect_Options{connect_method}) &&
      ($Connect_Options{connect_method} eq "local")) {
    title_append($Title_Local);
  }
}

######################################################################
#
# Find and parse host options
#

my $options = find_host_options($target);

if (defined($options)) {
  parse_host_options($options);
}

######################################################################
#
# Set any options not yet set
#

defined($Connect_Options{connect_method}) ||
  ($Connect_Options{connect_method} = "ssh");

######################################################################
#
# Build command to execute
#

my @command = ();

if ($Connect_Options{connect_method} eq "local") {

  @command = @ARGV;

} else {
  # Remote conect

  my $method = $Connect_Options{connect_method};

  push(@command, $Binaries{$method});

  # Options that go before the hostname
  if ($method eq "rlogin") {
    # Turn on encryption
    unless ($Connect_Options{cleartext}) {
      push(@command, "-x");
      title_append($Title_Krb5_Encrypt);
    }

    # Add remote username
    if (defined($Connect_Options{remoteuser})) {
      push(@command, "-l", $Connect_Options{remoteuser});
    }

  } elsif ($method eq "ssh") {
    # Add remote username
    push(@command, "-l", $Connect_Options{remoteuser})
      if defined($Connect_Options{remoteuser});

    title_append($Title_SSH);

  } elsif ($method eq "telnet") {
    # Turn on encryption
    unless ($Connect_Options{cleartext}) {
      push(@command, "-x");
      title_append($Title_Krb5_Encrypt);
    }
  }

  push(@command, $Connect_Options{remotehost});

  # Options that go after the hostname
  if ($method eq "telnet") {
    push(@command, $Connect_Options{port})
      if (defined($Connect_Options{port}));
  }
}


######################################################################
#
# Build xterm command
#

# Mappings of Xterm_Options to actual xterm command-line options
my %xterm_arg_mappings = (
			  "fg"     => \$Xterm_Options{foreground},
			  "bg"     => \$Xterm_Options{background},
			  "geometry" => \$Xterm_Options{geometry},
			  "ls"     => "login_shell",
			  "n"      => \$Xterm_Options{title},
			  "sb"     => "scrollbar",
			  "si"     => "inhibit_output_scroll",
			  "sk"     => "inhibit_key_scroll",
			  "t"      => "tek_window",
			  "T"      => \$Xterm_Options{title},
			  "vb"     => "visual_bell"
			 );
my @xterm_cmd = ();

push(@xterm_cmd, $Binaries{$Xterm_Options{program}});

arg: foreach my $arg (keys(%xterm_arg_mappings)) {
  my $value = $xterm_arg_mappings{$arg};

  if (ref($value)) {
    # Value if reference to variable we should use as value for options
    defined($$value) or next arg;

    push(@xterm_cmd, "-" . $arg, $$value);
    next arg;
  }

  # Value is key into %Xterm_Options
  my $option = $Xterm_Options{$value};

  defined($option) or next arg;

  push(@xterm_cmd, ($option ? "-" : "+") . $arg);
}

######################################################################
#
# Tell shell not to change xterm title if so requested
#

if ($Xterm_Options{titlechange}) {
  undef($ENV{NO_XTERM_TITLE_CHANGE}) if defined($ENV{NO_XTERM_TITLE_CHANGE});
} else {
  $ENV{NO_XTERM_TITLE_CHANGE} = 1;
}

######################################################################
#
# Build final command and execute

my @cmd = @xterm_cmd;

push(@cmd, "-e", @command) if ($#command > -1);

$Options{debug} && print join(' ', @cmd) . "\n";

exec(@cmd) || die "Failed to execute \"" . $cmd[0] . "\": $!";

######################################################################
#
# read_config_file
#
# Arguments: Filename
# Returns: Reference to hash
#

sub read_config_file {
  my $filename = shift;

  open(config_file, "<$filename") ||
    die "Could not open $filename: $!";

 LINE: while(<config_file>) {
    # Strip comments
    s/\#.*//;

    # Skip empty lines
    next LINE if (/^\s*$/);

    # Parse the line
    if (/^\s*host\s+(.*)\s*:\s*(.*)/) {

      my @lvalues = split(',', $1);
      my @values = split(',', $2);

      foreach my $lvalue (@lvalues) {
	# Strip leading and trailing whitespace
	$lvalue =~ s/^\s+//;
	$lvalue =~ s/\s+$//;

	$Host_Options{$lvalue} = \@values;
      }
    } elsif (parse_option($_)) {
      next LINE;

    } else {
      print STDERR "Error parsing line $. of $filename\n";
      next LINE;
    }

  }

  close(config_file);

  return 1;
}

######################################################################
#
# parse_host_options
#
# Arguments: Reference to array
# Returns: Nothing
#

sub parse_host_options {
  my $options = shift;

 OPTION: foreach my $option (@$options) {

    parse_option($option) ||
      print STDERR "Error parsing option \"$option\"\n";
  }
}


######################################################################
#
# parse_option
#
# Arguments: Option string
# Returns: 1 on success, 0 on error
#

sub parse_option {
  my $option = shift;

  # Strip leading and trailing whitespace
  $option =~ s/^\s+//;
  $option =~ s/\s+$//;

  if ($option =~ /use\s+(rlogin|ssh|telnet)/) {
    $Connect_Options{connect_method} = $1;
    return 1;

  } elsif ($option =~ /title\s+(.*)/) {
    $Xterm_Options{title} = $1;
    $Xterm_Options{title_no_modify} = 1;

  } elsif ($option =~ /remoteuser\s+(.*)/) {
    $Connect_Options{remoteuser} = $1;

  } elsif ($option =~ /remotehost\s+(.*)/) {
    $Connect_Options{remotehost} = $1;

  } elsif ($option =~ /domain\s+(.*)/) {
    $Connect_Options{remotehost} .= "." . $1;

  } elsif ($option =~ /(rlogin|ssh|telnet)\s+(.*)/) {
    $Binaries{$1} = $2;

  } else {

    # Parse error
    return 0;
  }
}


######################################################################
#
# find_host_options()
#
# Arguments: Target
# Returns: Reference to options array
#

sub find_host_options {
  my $target = shift;

  foreach my $host (keys(%Host_Options)) {
    # Convert regexes to perl style
    $regex = $host;
    $regex =~ s/\./\\./g;
    $regex =~ s/\*/\.\*/g;
    $regex =~ s/\?/\./g;

    if ($target =~ /$regex/) { return $Host_Options{$host}; }
  }

  return $Host_Options{DEFAULT} if defined($Host_Options{DEFAULT});

  return undef;
}


######################################################################
#
# title_append()
#
# Append a string to the title.
#
# Arguments: String
# Returns: Nothing
#

sub title_append {
  my $string = shift;

  return if (!defined($string) || ($string eq ""));

  return if ($Xterm_Options{title_no_modify});

  $Xterm_Options{title} .= " " . $string;
}
