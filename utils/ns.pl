#!/usr/local/bin/perl
######################################################################
#
# ns - Open a netscape window with file.
#
######################################################################

use Cwd;
use Cwd 'abs_path';
use File::Spec;

######################################################################

my $target = shift || cwd();

$target = File::Spec->catfile(cwd(), $target)
  unless File::Spec->file_name_is_absolute($target);

$target = File::Spec->canonpath($target);
$target =~ s/\.$//;

my @Cmd = ("netscape");
push(@Cmd, "-remote");
push(@Cmd, "openURL(file://$target, new-window)");

system(@Cmd);
