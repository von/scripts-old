#!/usr/bin/env perl
######################################################################
#
# cvs-make-release
#
# Export a CVS repository and make a release.
#
# $Id$
#
######################################################################

require 5.001;

use Carp;

######################################################################
#
# Default configuration
#

$configuration = {
		  # cvs binary to run
		  cvs                       => "cvs",
		  # tar binary to run
		  tar                       => "tar",
		  # binary to use to compres
		  gzip                      => "gzip",
		  # cvsroot to use
		  cvsroot                   => undef,
		  # repository
		  module                    => undef,
		  # Base name of tarball
		  package_name              => "%m-%t",
		  # Tag to use if version is given
		  tag                       => "%m-%v",
		  # Command to run after export
		  post_export_command       => undef,

		  # Root of configuration
		  _config_dir               => undef,
		  # Tag/date of exported version
		  _tag                      => undef,
		  # -v option if given
		  _version                  => undef,
		 };

defined($ENV{HOME}) &&
  ($configuration->{_config_dir} = $ENV{HOME} . "/.cvs_make_release/");

######################################################################
#
# Mapping between % characters and configuration values
#

$Percent_Mappings = {
		     m => "module",
		     t => "_tag",
		     v => "_version",
		    };

######################################################################
#
# Functions to run at exit
#

@AtExit = ();

######################################################################
#
# Main code
#

# Parse commandline options

use Getopt::Std;

my %opt;

getopts('D:r:v:', \%opt);

# Make sure only one of -D, -r and -v was given
my $count = defined($opt{D}) + defined($opt{r}) + defined($opt{v});
($count > 1) && error("Can only supply one option of -D, -r and -v\n");


my $module = shift;

defined($module) || error("Must supply a module name\n");

$configuration->{module} = $module;

($#ARGV > 0) && warn("Ignoring extra arguments starting with %s", shift);

######################################################################
#
# Read configuration, both general and module-specific
#

get_configuration($configuration);

######################################################################
#
# Make and change to working directory
#

# First save our current directory
use Cwd;
my $starting_directory = cwd();

my $index = 0;
my $working_dir_basename = "/tmp/cvs_make_release.$$";
my $working_dir = $working_dir_basename;

while (-e $working_dir)
{
  $working_dir = $working_dir_basename . "." . $index;
  $index++;
}

# Make sure we delete this on exit
push(@AtExit,
     sub { print "Removing $working_dir\n";
	   system("rm -rf $working_dir"); });

message("Creating working directory $working_dir");

mkdir($working_dir, 0700)
    || error("Could not make working directory \"%s\": $!", $working_dir);

chdir($working_dir) || error("Could not cd to working directory \"%s\": $!",
			     $working_dir);

######################################################################
#
# Figure out the name of the directory we are going to export to
#

# First we need to look back to command-line options and figure
# out what the user wants.
if ($opt{D})
{
  $configuration->{_tag} = $opt{D};
}

if ($opt{r})
{
  $configuration->{_tag} = $opt{r};
}

if ($opt{v}) {
  my $vers = $opt{v};

  # Convert 'x.y.z' to 'x_y_z'
  $vers =~ s/\./_/g;


  $configuration->{_tag} = $opt{v};
}

!defined($configuration->{_tag}) &&
  ($configuration->{_tag} = "now");

my $package_name = percent_parse($configuration,
 				 $configuration->{package_name});

message("Will export to $package_name");

######################################################################
#
# Build and run the cvs command
#

my $cvs_cmd = $configuration->{cvs};

my $cvsroot = $configuration->{cvsroot};

defined($cvsroot) && ($cvs_cmd .= " -d " . $cvsroot);

$cvs_cmd .= " export";

my $tag = undef;
$opt{r} && ($tag = "-r " . $opt{r});
$opt{D} && ($tag = "-D " . $opt{D});

if ($opt{v})
{
  my $version = $opt{v};

  # convert format from "x.y.z" to "x_y_z"
  $version =~ s/\./_/g;

  $configuration->{_version} = $version;

  $tag = "-r " . percent_parse($configuration,
			       $configuration->{tag});
}

# If no tag given, then get head of tree
!defined($tag) && ($tag = "-D now");

$cvs_cmd .= " " . $tag;

$cvs_cmd .= " -d $package_name";

$cvs_cmd .= " " . $configuration->{module};

message("Running $cvs_cmd");

my $rc = system($cvs_cmd) >> 8;

# Not sure if the return code tells us anything

(-d $package_name) ||
  error("cvs failed to export %s", $configuration->{module});

######################################################################
#
# Now run any post export commands
#

if (defined($configuration->{post_export_command}))
{
  message("Executing post-export command \"%s\"",
	  $configuration->{post_export_command});

  my $cmd = "cd $package_name;";
  $cmd .= $configuration->{post_export_command};

  system($cmd);
}

######################################################################
#
# Now tar it up
#

# Name of the tarball
my $tarball = $package_name . ".tar";
my $tarball_fullname = $starting_directory . "/" . $tarball;

message("Making tarball $tarball");

$cmd = $configuration->{tar};
$cmd .= " cf";
$cmd .= " $tarball_fullname";
$cmd .= " $package_name";

system($cmd);

( -e $tarball_fullname) || error("tar failed to creat $tarball");

# And compress
my $tarball_gz = $tarball . ".gz";
my $tarball_gz_fillname = $tarball_fullname . ".gz";

message("Compressing $tarball");

$cmd = $configuration->{gzip};
$cmd .= " $tarball_fullname";

system($cmd);

######################################################################
#
# Finished.
#

message("$tarball_gz created.");

cleanup();

exit(0);

#
# End main code
#
######################################################################

######################################################################
#
# cleanup
#
# Call cleanup functions. Should be called before exiting.
#
# Arguments: None
# Returns: Nothing

sub cleanup
{
  foreach my $function (@AtExit)
  {
    &$function();
  }
}

######################################################################
#
# error
#
# Print error message and die.
#
# Arguments: Arguments to printf
# Returns: Doesn't

sub error
{
  warning(@_);

  cleanup();

  exit(1);
}

######################################################################
#
# warning
#
# Print warning message
#
# Argumrnts: Arguments to printf
# Returns: 1

sub warning
{
  my $format = shift;

  chomp($format);
  $format .= "\n";

  my $message = sprintf($format, @_);

  print STDERR $message;

  return(1);
}

######################################################################
#
# message
#
# Print a message to the user
#
# Argumrnts: Arguments to printf
# Returns: 1

sub message
{
  my $format = shift;

  chomp($format);
  $format .= "\n";

  my $message = sprintf($format, @_);

  print $message;

  return(1);
}


######################################################################
#
# get_configuration
#
# Read our configuration and the module configuration.
#
# Arguments: Reference to configuration
# Returns: Nothing, dies on error

sub get_configuration
{
  my $configuration = shift;
  (ref($configuration) eq "HASH") || confess "Bad configuration argument";

  my $conf_dir = $configuration->{_config_dir};

  defined($conf_dir) || error("Cannot determine configuration directory");

  my $module_dir = $conf_dir . "modules/";

  -d $module_dir || error("modules directory \"$module_dir\" does not exist");

  my $module_conf_file = $module_dir . $configuration->{module};

  read_module_file($configuration, $module_conf_file);

  return(1);
}

######################################################################
#
# read_module_file
#
# Read the given module configuration file.
#
# Arguments: Reference to configuration, filename
# Returns: Nothing, dies on error

sub read_module_file
{
  my $configuration = shift;
  (ref($configuration) eq "HASH") || confess "Bad configuration argument";

  my $filename = shift;
  defined($filename) || confess "Bad filename argument";

  open(CONF, "<$filename") ||
    die "Could not open $filename for reading: $!";

 line: while (<CONF>)
  {
    # Remove comments
    s/#.*$//;

    # skip blank lines
    next if (/^\s*$/);

    # Otherwise should be configuration option
    if (/^\s*(\w+)\s*=\s*\"([^\"]*)\"\s*/ ||
	/^\s*(\w+)\s*=\s*(.*)\s*$/)
    {
      my $variable = $1;
      my $value = $2;

      if (($variable =~ /^_/) ||
	  !exists($configuration->{$variable})) {
	warning("Unknown variable \"$variable\" on line $. of $configuration_filename");
	next line;
      }

      $configuration->{$variable} = $value;
      next line;
    }
    else
    {
      warning("Could not parse line $. of $configuration_filename");
    }

    warning("Could not parse line $. of $configuration_filename");
    next line;
  }

  close(CONF);

  return(1);
}


######################################################################
#
# percent_parse
#
# Return a string performing substitutions for various percent characters.
#
# Uses Percent_Mappings global.
#
# Arguments: Configuration refernce, string
# Returns: String

sub percent_parse
{
  my $configuration = shift;
  (ref($configuration) eq "HASH") || confess "Bad configuration argument";

  my $string = shift;
  defined($string) || confess "Bad string argument";

  $string =~ s/%(\w)/$configuration->{$Percent_Mappings->{$1}}/g;

  return $string;
}

__END__

######################################################################
#
# POD documentation
#

=head1 NAME

cvs-make-release

=head1 SYNOPSIS

cvs-make-release <options> module

cvs-make-release reads a configuration file in the user's home directory
and uses the given information to export, configure and make a tarball
of the requested module.

=head1 DESCRIPTION

cvs-make-release reads the commandline to determine the module the
user is requesting be exported. It then reads the configuration file
for that module in F<$HOME/.cvs-make-release/><module name>. It will
then create a temporary directory, export the module, do any needed
configuration and then tar up the module leaving the resulting
tarball in the current directory.

One of the options B<-D>, B<-r>, and B<-v> may be used to indicate
a date, tag or version of the module to export respectively. If none
of these options are given the head of the cvs tree is exported.

=head1 COMMANDLINE ARGUMENTS

cvs-make-release accepts the following commandline options:

=over 4

=item -D I<date>

Indicate a date to use for export. This date is passed directory to
cvs.

=item -r I<tag>

Indicate a tag to use for export. This tag is passed directory to
cvs.

=item -v I<version>

Indicate a version to use for export. This cases cvs-make-release to
use the I<tag> option in the configuration file to determine what
tag to use.

=back

=head1 CONFIGURATION FILES

When a module is requested cvs-make-release looks in the directory
F<$HOME/.cvs-make-release/modules/> for a configuration file with the
same name as the module.

Items in the configurtion file may contain the following strings
which are replaced at runtime:

=over 4

=item m

The name of the module.

=item t

The name of the tag being used for export.

=item v

The version of the module being exported.

=back

The file may contain the following lines:

=over 4

=item # <command>

Any text between a pound sign and the end of the line is treated as
a comment and ignored.

=item cvsroot=<root>

The cvsroot to use for this module.

=item package_name=<tarballl name>

The base name of the tarball to be created. Default is "%m-%t".

=item post_export_command=<shell command>

A command to be run in the export directory after the package
is exported. For example: "autoreconf".

=item tag=<tag string>

The string used to generate a tag if a version is given. Default is
"%m-%v".

=back

=head1 SEE ALSO

cvs(1)

=head1 AUTHOR

Von Welch <vwelch@ncsa.uiuc.edu>

=cut
