#!/usr/bin/perl
######################################################################
#
# html_view
#
# Dump stdin to netscape for viewing.
#
######################################################################

my $file = shift;

# Need to copy the document because as soon as we exit the calling
# application (e.g. mutt) may remove it
my $newfile="/tmp/htmlview.$$";
system("cp $file $newfile");

system("netscape -remote openURL\\($newfile,new-window\\)");
