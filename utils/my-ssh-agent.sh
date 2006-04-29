#!/bin/sh
######################################################################
#
# my-ssh-agent
#
# Start ssh-agent and save info to file.
#
######################################################################

# exit on any error
set -e

host=`hostname | awk -F. '{print $1}' -`

agent_dir=$HOME/.ssh/$host

agent_file=${agent_dir}/agent

if [ ! -d $agent_dir ]; then
  mkdir $agent_dir
fi

ssh-agent -a $agent_file > ${agent_dir}/log 2>&1
