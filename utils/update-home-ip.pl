#!/usr/bin/env perl
######################################################################

=head update-home-ip.pl

Meant to be executed via ssh from a system at home to update my home's
IP address in a bunch of file on a remote system (yes, a poor man's
dynamic DNS).

Looks for client IP information in the SSH_CLIENT environment variable
and if the IP has changed, update a bunch of files.

Has a built in list of files (yes, To Do, fix this) which it will scan
for strings that look like:
C<&lt;!--HOME-IP--&gt1.2.3.4&lt--END-HOME-IP--&gt;> and update the IP
address if it has changed.


=cut

use File::Copy;
use File::Temp;

######################################################################
#
# Configuration
#

# List of file to files to update:
my @fileList = (
    "/tmp/testFile.html"
    );

######################################################################
my $sshClient = $ENV{SSH_CLIENT};

if (!defined($sshClient))
{
    errorExit("SSH_CLIENT environment variable not defined.");
}

# This variable should look like "SSH_CLIENT=98.222.63.70 60143 2222"
# I.e. <client ip> <client port> <server port>
my $homeIP = undef;
if ($sshClient =~ /(\d+\.\d+\.\d+\.\d+) (\d+) (\d+)/)
{
    $homeIP = $1;
    # Client port is $2
    # Server port is $3
}
else
{
    errorExit("Could not parse SSH_CLIENT ($sshClient).");
}

# OK, $homeIP now contains our home IP address.
for my $filename (@fileList)
{
    message("Processing $filename...\n");
    processFile($filename, $homeIP);
}

sub processFile
{
    my $filename = shift;
    my $homeIP = shift;

    my ($tempHandle, $tempFilename) = File::Temp::tempfile(UNLINK=>1);

    my $fileHandle;
    if (!open($fileHandle, $filename))
    {
	error("Could not open $filename for reading: $!");
	return;
    }
    # Have we made a change that means we need to update file?
    my $madeChange = 0;

    while (<$fileHandle>)
    {
	if (/<!--HOME-IP-->(\d+\.\d+\.\d+\.\d+)<!--END-HOME-IP-->/)
	{
	    my $ip = $1;
	    if ($ip ne $homeIP)
	    {
		message("Updating old IP of $ip\n");
		s/<!--HOME-IP-->(\d+\.\d+\.\d+\.\d+)<!--END-HOME-IP-->/<!--HOME-IP-->$homeIP<!--END-HOME-IP-->/g;
		$madeChange = 1;
	    }
	}
	print $tempHandle $_;
    }
    close($fileHandle);
    close($tempHandle);
    
    # If we made a change, copy temporary file over original
    if ($madeChange)
    {
	message("Updating $filename...\n");
	if (!move($tempFilename, $filename))
	{
	    error("Could not update $filename: $!");
	    return;
	}
    }
}

sub message
{
    my $format = shift;
    chomp($format);
    my $msg = sprintf($format, @_);
    print $msg . "\n";
}

sub error
{
    my $format = shift;
    chomp($format);
    my $msg = sprintf($format, @_);
    print STDERR $msg . "\n";
}

sub errorExit
{
    error(@_);
    exit(1);
}

		 
    

