#!/bin/sh
###########################################################################
#
#	Cleanup httpd logs
#
#	1) Parse access_log
#	2) cat error_log
#	3) Remove old log files
#	4) Rename current log files
#	5) Restart httpd
#	6) Compress (now old) log files
#
#
#	$Id$
#
###########################################################################
#
#	Subroutines
#

#
# Write some text to a log
#	Arguments: <text...>
#
log()
{
  echo $* >> $log_file ;
}
  
#
# Run a command, logging it's output and returning it's return code
#	Arguments: <command> <args...>
#
cmd_log()
{
  $* >> $log_file 2>&1 ;
}

###########################################################################
#
# Parse command line arguments
#

if [ $# -ne 2 ]; then
  echo "Usage: $0 <www dir> <user>"
  exit 1;
fi

www_dir=$1
shift

user=$1
shift

###########################################################################
#
# Set some defaults
#

log_dir=$www_dir/logs

bin_dir=`dirname $0`

parse_cmd=$bin_dir/httpd.access.parse

log_file=/tmp/http.parse.$$

compress_cmd="/bin/compress -f"

###########################################################################

log "-----------------------------------------------------------------"
log ""
log "HTTPD cleanup cron job"
log "  Directory: $www_dir"
log ""

cd $log_dir

log "-----------------------------------------------------------------"
log ""
log "Error log:"
log ""
cmd_log cat error_log
log ""
log "-----------------------------------------------------------------"
log ""
log "-----------------------------------------------------------------"
log ""
cmd_log $parse_cmd access_log
log ""
log "-----------------------------------------------------------------"
log ""

for file in *.old.Z *.old ; do
  log "Removing backup log: $file"
  cmd_log /bin/rm -f $file
done

log ""

for file in *_log ; do
  log "Renaming $file"
  cmd_log /bin/mv $file $file".old"
done

log ""

log "Restarting HTTPD."
cmd_log /bin/kill -1 `/bin/cat httpd.pid`

log ""

for file in *.old; do
  if [ -s $file ]; then
    log "Compressing $file"
    cmd_log $compress_cmd $file
  else
    log "No need to compress $file (0 length)."
  fi
done

cat $log_file | /usr/ucb/Mail -s "HTTPD Cleanup Job ($www_dir)" $user
rm -f $log_file

#
# End code.
#
###########################################################################
