#!/bin/sh
######################################################################
#
# cpdir
#
# Copy a directory tree
#
# $Id$
#
######################################################################

src=$1
dst=$2

tar="tar"
mktar_args="cf"
untar_args="xf"

######################################################################

if [ ! -d $dst ]; then
  mkdir -p $dst
fi

(cd $src ; $tar $mktar_args - * ) | (cd $dst ; $tar $untar_args - )
