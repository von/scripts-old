#!/bin/sh
###########################################################################
#
#	xtool
#
###########################################################################
#
command_dir=$HOME/.xtool
#
###########################################################################
#
run_quiet()	{ $* > /dev/null 2>&1; }
exec_quiet()	{ exec $* > /dev/null 2>&1; }
#
###########################################################################
#
tool=$1
shift
#
# Change to home directory
#
cd $HOME
export PWD
PWD=$HOME
#
# Check for command file
#
command_file=$command_dir"/"$tool
#
if [ -r $command_file ]; then
	. $command_file

else	# Punt
	exec $tool $*
fi
