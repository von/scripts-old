#!/bin/sh
name=$1

if [ -z "$name" ]; then
  name="default"
fi

screen_opts=""

# Big scroolback buffer
screen_opts="${screen_opts} -h 1200"

# Set xterm title
host=`hostname`
title="Screen@${host}:${name}"
echo -n "]1;${title}]2;${title}"

screen $screen_opts -r $name || screen $screen_opts -d -r $name || screen $screen_opts -S $name
