#!/usr/local/bin/perl
######################################################################
#
# logwatch
#
# Log-watching program based on swatch.
#
# $Id$
#
######################################################################
#
# Functions to be called for various actions
#

%Functions = (
	      bell            => \&function_bell,
	      email           => \&function_email,
	      exec            => \&function_exec,
	      ignore          => \&function_ignore,
	      pipe            => \&function_pipe,
	      print           => \&function_print,
	      write           => \&function_write,
	      );

######################################################################
#
# Print attributes and their escape sequences
#
# Kudos to swatch script for these.
#

$Bell = "\\007";

%PrintAttributes = (
		    black	 => "\\033[30;1m",
		    red		 => "\\033[31;1m",
		    green	 => "\\033[32;1m",
		    yellow	 => "\\033[33;1m",
		    blue	 => "\\033[34;1m",
		    magenta	 => "\\033[35;1m",
		    cyan	 => "\\033[36;1m",
		    white	 => "\\033[37;1m",
		    black_h	 => "\\033[40;1m",
		    red_h	 => "\\033[41;1m",
		    green_h	 => "\\033[42;1m",
		    yellow_h	 => "\\033[43;1m",
		    blue_h	 => "\\033[44;1m",
		    magenta_h	 => "\\033[45;1m",
		    cyan_h	 => "\\033[46;1m",
		    white_h	 => "\\033[47;1m",
		    bold         => "\\033[1m",
		    blink        => "\\033[5m",
		    inverse      => "\\033[7m",
		    normal       => "\\033[0m",
		    underscore   => "\\033[4m",
		);

######################################################################
#
# Configuration and defaults
#

my %Config = (
	      # File to monitor
	      log_files          => undef,
	      # Number of lines at end to parse
	      tail_lines         => 0,
	      # Configuration file
	      config_file        => "/usr/local/etc/logwatchrc",
	      # How often to check the file to see if it's inode has changed
	      check_time         => 10,
	      # Mail program
	      email_program       => "mail",
	      # Tail program
	      tail_program       => "tail",
	      # Default subject for email
	      email_default_subject       => "** Attention **",
	      # Default address for email
	      email_default_to            => undef,
	      # Signal to kill tail with
	      tail_kill_signal   => 2,
	     );


######################################################################
#
# Parse command line arguments
#

use Getopt::Std;

my %opt;
my $arg_error = 0;

# This '||' doesn't work in all versions of perl
getopts('c:n:D', \%opt) || ($arg_error = 1);

$Config{config_file} = $opt{c}                  if $opt{c};
$Config{tail_lines} = $opt{n}                   if $opt{n};
$Config{debug} = $opt{D};

read_config_file($Config{config_file});

$Config{log_files} = \@ARGV if scalar(@ARGV);

if (!scalar(@{$Config{log_files}})) {
    print STDERR "Name of logfile required\n";
    $arg_error = 1;
}

if ($arg_error == 1) {
    # XXX usage
    exit(1);
}

######################################################################
#
# Set up signals
#

# SIGHUP should restart our parsing
$SIG{HUP} =  \&reload;

# Set up alarm to check inode

$SIG{ALRM} = \&check_inodes;

alarm $Config{check_time};


######################################################################
#
# Dump code if we are debuggng
#
print $Code if $Config{debug};

######################################################################
#
# Build tail command
#
my @tail_cmd = ();

push(@tail_cmd, $Config{tail_program});

# Continuous tail
push(@tail_cmd, "-f");

# Don't print file name headerse have multiple files
push(@tail_cmd, "-q") if (scalar(@{$Config{log_files}}) > 1);

# Start with this many tail lines
push(@tail_cmd, "-n", $Config{tail_lines});

push(@tail_cmd, @{$Config{log_files}});

my $tail_cmd = join(' ', @tail_cmd);

######################################################################
#
# Main loop
#

while(1) {
  $Log_File_Inodes = get_inodes(@{$Config{log_files}});

  $Tail_PID = open(LOG_FILE, "$tail_cmd|") ||
    die "Could not exec $Config{tail_program}: $!";

  while(<LOG_FILE>) {
    eval $Code;

    print $@ if $@;
  }

  close(LOG_FILE);

  my $status = $?;

  my $exit_value = $status >> 8;
  my $signal = $status & 127;

  ($exit_value != 0) && die "Could not execute tail ($Config{tail_program})";
  ($signal != $Config{tail_kill_signal}) && die "tail died from signal $signal";

  # Looks like tail was killed by check_inodes(), so just return to top
  # of while loop and start over.
}

exit(0);

######################################################################
#
# Subroutines
#

#
# check_inodes
#
# Check the inodes of the log files and if any have changed, kill
# the tail so that it will be restarted.
#
# Arguments: Signal
# Returns: Nothing

sub check_inodes {
 log_file: foreach my $log_file (@{$Config{log_files}}) {
    my $current_inode = get_inode($log_file);
    my $previous_inode = $Log_File_Inodes->{$log_file};

    if ($current_inode != $previous_inode) {
      print "Inode of " . $log_file . " changed. Restarting.\n";
      kill $Config{tail_kill_signal}, $Tail_PID;
      last log_file;
    }
  }

  alarm $Config{check_time};
}

#
# reload
#
# Reload our configuration.
#
# Arguments: Signal
# Returns: Nothing

sub reload {
  my $signal = shift;

  print "Caught SIG$signal. Reloading configuration\n";

  read_config_file($Config{config_file});
}

#
# read_config_file
#
# Read and parse the configuration file.
#
# Arguments: Filename
# Returns: Nothing, modifies globals

sub read_config_file {
  my $filename = shift;

  $Code = "";

  open(CONFIG, "<$filename") ||
    die "Could not open $filename for reading: $!";

 config: while(<CONFIG>) {
    chomp;

    # Deal with backslash-escaped carraige returns
    if (s/\\$//) {
      $_ .= <CONFIG>;
      redo config unless eof();
    }

    # Ignore comments
    next if/^\s*\#/;

    # Ignore blank lines
    next if /^\s*$/;

    # Line should be "/regex/ action [, action2] [,action3]"
    if (/^\s*(\/.*\/)\s+(.*)$/) {
      my $regex = $1;
      my @actions = split(/\s*,\s*/, $2);

      $Code .= "if ($regex) {\n";

    action: foreach my $action (@actions) {
	my @fields = tokenize($action);

	my $directive = shift(@fields);

	my $function = $Functions{$directive};

	if (!defined($function)) {
	  print STDERR "Unrecognized action \"$directive\" on line $. of $filename\n";
	  next action;
	}

	$Code .= "\t# Code for $action\n";
	$Code .= &$function(@fields);
      }

      $Code .= "\tnext;\n";
      $Code .= "}\n";

      next config;
    }

    # Parse "log_files" specially
    if (/^\s*log_files\s+(.*)\s*$/) {
      my @log_files = split(' ', $1);
      $Config{log_files} = \@log_files;
      next config;
    }

    # Check for Config values
    if (/^\s*(\S+)\s+(.*)\s*$/ && exists($Config{$1})) {
      $Config{$1} = $2;
      next config;
    }

    # Unrecognized line
    print STDERR "Cannot parse line $. of $filename.\n";
  }

  close(CONFIG);
}

#
# get_inode
#
# Return the inode of the give file.
#
# Arguments: Filename
# Returns: inode, undef on error

sub get_inode {
  my $filename = shift;

  return (stat($filename))[1];
}

#
# get_inodes
#
# Given an array of log files, return a reference to a has containing
# the inodes of all the log files keys by name.
#
# Arguments: Array of log file names
# Returns: Hash reference with inodes

sub get_inodes {
  my @files = @_;

  my $inodes = {};

  foreach my $file (@files) {
    $inodes->{$file} = get_inode($file);

    defined($inodes->{$file}) || die "Could not stat $file: $!";
  }

  return $inodes;
}

#
# email
#
# Send email.
#
# Arguments: [Addresses [, subject]]
# Returns: Nothing

sub email {
  my $address = shift || $Config{email_default_to};
  my $subject = shift || $Config{email_default_subject};
  my $mail = $Config{email_program};

  if (!open(MAIL, "|$mail -s \"$subject\" $address")) {
    print STDERR "Could not exec $mail: $!";
    return;
  }

  print MAIL;

  close(MAIL);
}

#
# tokenize
#
# Tokenize a string into tokens allowing them to be double-quote
# delimited.
#
# Arguments: String
# Returns: Array of tokens

sub tokenize {
    my $string = shift;

    my @tokens;

    while (length($string) != 0) {
	$string =~ /^\s*([^\"]\S*)\s*(.*)$/ ||
	  $string =~ /^\s*\"([^\"]*)\"\s*(.*)$/;

	push(@tokens, $1);
	$string = $2;
    }

    return @tokens;
}

#
# detokenize
#
# Convert a bunch of tokens into a string, quoting with escaped
# quotes where needed for easy inclusion into $Code.
#
# Arguments: Array of tokens
# Returns: String

sub detokenize {
  my $string = "";

  foreach my $token (@_) {
    if ($token =~ /\s/) {
      $string .= "\\\"$token\\\"";
    } else {
      $string .= $token;
    }

    $string .= " ";
  }

  # Remove extra trailing space
  $string =~ s/ $//;

  return $string;
}


#
# function_*
#
# Output to code to run for the given function.
#
# Arguments: [Arguments to function]
# Returns: Code string

sub function_ignore {
  return "\t# Do nothing\n";
}

sub function_bell {
  my $code = "";
  my $repetitions = shift || 1;

  $code .= "\tprint \"$Bell\"";
  $code .= "x $repetitions" if ($repetitions > 1);
  $code .= "; # Bell\n";

  return $code;
}


sub function_print {
  my $code = "";
  my $needs_normalization = 0;

  foreach my $attribute (@_) {
    my $escape_sequence = $PrintAttributes{$attribute};

    if (!defined($escape_sequence)) {
      print STDERR "Unrecognized print attribute \"$attribute\" on line $. of $Config{logfile}\n";
      next;
    }

    $needs_normalization = 1;

    $code .= "\tprint \"$escape_sequence\"; # $attribute\n";
  }

  # Remove CR so we can print normalization escape sequence before it
  # and not color up the next line.
  $code .= "\tchomp;\n"
    if $needs_normalization;

  $code .= "\tprint;\n";

  $code .= "\tprint \"$PrintAttributes{normal}\\n\"; # Normalize text\n"
    if $needs_normalization;

  return $code;
}

sub function_email {
  my $subject = "undef";           # Use default

  if ($_[0] eq "-s") {
    shift(@_);
    $subject = "\"" . shift(@_) . "\"";
  }

  my $addresses = join(' ', @_);

  if (($addresses eq "") && !defined($Config{email_default_to})) {
    print STDERR "Email must have address on line $. of $Config{logfile}\n";
    return "";
  }

  return "\temail(\"$addresses\", $subject);\n";
}

sub function_exec {
  my $code = "";

  my $command = detokenize(@_);

  if ($command eq "") {
    print STDERR "No command supplied on line $. of $Config{logfile}\n";
    return "";
  }

  $code .= "\tsystem(\"$command\");\n";

  return $code;
}

sub function_pipe {
  my $code = "";

  my $command = detokenize(@_);

  if ($command eq "") {
    print STDERR "No command supplied on line $. of $Config{logfile}\n";
    return "";
  }

  $code .= "
\topen(PIPE, \"|$command\") || print STDERR \"Could not exec $command: \$!\n\";
\tprint PIPE;
\tclose(PIPE);
";

  return $code;
}

sub function_write {
  my $code = "";
  my $filename = shift;

  if (!defined($filename)) {
    print "No filename supplied on line $. of $Config{logfile}\n";
    return "";
  }

  $code .= "
\topen(FILE, \">>$filename\") || print STDERR \"Could not open $filename: \$!\n\";
\tprint FILE;
\tclose(FILE);
";

  return $code;
}


__END__

######################################################################
#
# POD documentation

=head1 NAME

logwatch - monitor a logfile

=head1 SYNOPSIS

logwatch [<options>] [<filenames>]

logwatch is a script in the spirit of swatch. It uses tail to
monitor a file and using supplied regexes perform actions
based on contents of the file.

=head1 COMMANDLINE ARGUMENTS

=over 4

=item -c I<configuration file>

Spcify the configuration file to use. Default is
F</usr/local/etc/logwatchrc>

=item -D

Run in debug mode. Will print lots of extra goodies.

=item -n I<lines>

Number of lines of log file to parse from the end before settling in
to only parse new lines (like C<-n> option to tail). Default is 0.

=back

=head1 CONFIGURATION FILE

The configuration file can contain the following lines:

=over 4

=item # Comments

Any line starting with a pound sign (excluding white space) is ignored.

=item \ Backslash escape

A backslash appearing at the end of a line causes the next line to be
intrepreted as a continuation of the current line.

=item check_time <seconds>

How often to check the file to see if its inode has changed.
Default is 10 seconds.

=item email_program <program>

Program to run to send email. Default is "mail".

=item tail_program <program>

Program to run to monitor the file. Default is "tail".

=item tail_lines <lines>

Number of lines at end of file to parse. Default is 0.

=item email_default_subject <subject>

Default subject to use in send emails where one is not
provided in the action. Default is "** Attention **".

=item email_default_to <recipients>

Default recipients of email when not provided. There is
no default.

=item log_files <logfiles>

This line can be used to specify one or more whitespace-seperated logfiles.
If not log files are given on the command line these files will me tailed
by default.

=item /Regex/ I<action1> [I<args>][, I<action2> [I<args>]]...

A perl style regex between slashes followed by one or more
actions. See L<ACTIONS> for a list of actions.

=back

=head1 ACTIONS

=over 4

The following actions are recognized:

=item bell

Causes the bell to be rung.

=item email [-s I<subject>] [I<recipients>]

Email the line to the listed recipients. I<subject> may be provided
and should be quoted if it contains whitespace. If no recipients
are given the email_default_recipients value must be provided and
it will be used instead.

=item exec I<command>

Execute the given command.

=item ignore

The line is ignored and no further processing will be done.

=item pipe I<command>

Execute the given command, and pipe the matching line from the
logfile to it on the standard input.

=item print [I<modifiers>]

The line is printed. Without modifiers it is printed in normal text.
The following modifieres are recognized and may be combined:

     bold        The item will be printed in bold.
     blink       The item will be printed in blinking text.
     inverse     The item will be printed in inverted text.
     underscore  The item will be printed in unscored text.

Additionally the following colors are recognized: black, red, green,
yellow, blue, magenta, cyan, white. Color names with a "_h" suffix are
also recognized to indicate a highlighted version of the color should
be used. Combining colors results in all but the last color listed
being ignored.

=item write I<filename>

Write the matching line to the given file.

=back

=head1 EXAMPLE CONFIGURATION FILE

  #
  # Example configuration file
  #
  log_files    /var/log/messages \
               /var/log/secure

  # Ignore any line with the word ignore in it
  /ignore/	ignore

  # Any line with the word email email to root and also print it
  /email/		email root, print

  # Any line with any of the modifiers get printed with the modifier
  /bold and inverse/	print bold inverse
  /bold/		print bold
  /blink/		print blink
  /inverse/		print inverse
  /under/		print underscore

  # Everything else get printed
  /.*/		print

=head1 TODO

=over 4

=item *

If a the inode of a file has changed we want to start reading from the
begining of the file.

=item *

Should always print unless specified otherwise

=item *

Ability to parse swatchrc files (2.x and 3.x?)

=item *

select() seems to be broken on my machine. It would be nice if it
worked so that I didn't need to us the tail program. I should also
investigate File::Tail.

=item *

Allow for parsing file without tailing.

=back

=head1 ACKNOWLEDGEMENTS

The whole concept of this program is based off of swatch
(http://www.engr.ucsb.edu/~eta/swatch/) but all the code is my own,
though I did grab the escape sequences for the print attributes
from swatch.

Why did I right my own program instead of using swatch? Well at the
time (before swatch 3.x), I thought swatch development was dead. I
also wanted to see if I could do the same thing using eval instead of
making a whole new script, which I did and I think it results in a
much cleaner program.

=head1 AUTHOR

Von Welch (vwelch@ncsa.uiuc.edu)

=cut

