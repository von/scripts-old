#!/bin/sh
######################################################################
#
# fetchmail-util
#
# Script for running fetchmail pre and post connect commands.
#
# $Id$
#
######################################################################

# XXX Should be user-specific
ssh_pid_file=/tmp/fetchmail-ssh-pid

######################################################################

display_message () {
  message=$1

  echo "$message"

  xmessage -center "$message" &
}

use_krb5_cache () {
  cache=$1
  expired=${cache}-expired

  # Check to make sure cache is valid
  if klist -s $cache ; then
    rm -f $expired
  else
    echo "krb5 cache $cache expired"
    if [ ! -f $expired ]; then
      display_message "Krb5 cache $cache expired" &
      touch $expired
    fi
    exit 1
  fi

  rm -f /tmp/krb5cc_fetchmail
  ln -s $cache /tmp/krb5cc_fetchmail
}

######################################################################

set -e

command=$1
shift

server=$1
shift

case $command in
pre)
  case $server in
  mallorn)

    echo -n "Checking Mallorn: "
    date
    
    use_krb5_cache /tmp/krb5cc_vwelch_mallorn

    ;;

  mcs)
    echo -n "Checking MCS: "
    date

    if [ -f $ssh_pid_file ]; then
      ssh_pid=`cat $ssh_pid_file`
      rm -f $ssh_pid_file
      ps aux | grep -v grep | grep $ssh_pid > /dev/null && kill $ssh_pid || /bin/true
    fi

    /usr/bin/ssh -n -a -L 2143:imap.mcs.anl.gov:143 -l welch terra.mcs.anl.gov sleep 20 < /dev/null > /dev/null &
    echo $! > $ssh_pid_file

    # Hack to give ssh a chance to start up (1 second not always enough)
    sleep 2
    ;;

  *)
    echo "Unknown server: $server"
    exit 1
    ;;
  esac
  ;;

post)
  case $server in
  mallorn)
    echo "Mallorn done."
    ;;

  mcs)
    echo "MCS done."
    ;;

  *)
    echo "Unknown server: $server"
    exit 1
    ;;
  esac
  ;;

*)
  echo "Unknown command: $command"
  exit 1
  ;;
esac

exit 0
