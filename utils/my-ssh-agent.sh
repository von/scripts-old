#!/bin/sh
######################################################################
#
# my-ssh-agent
#
# Start ssh-agent and save info to file.
#
######################################################################

agent_dir=$HOME/.ssh-agent

# exit on any error
set -e

if [ ! -d $agent_dir ]; then
  echo "Making $agent_dir"
  mkdir $agent_dir
fi

host=`hostname | awk -F. '{print $1}' -`

# Remove echo line
ssh-agent | grep -v echo > $agent_dir/$host
