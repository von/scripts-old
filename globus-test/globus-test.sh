#!/bin/sh
######################################################################
#
# globus-test
#
# Test out globus commands to a remote system.
#
# $Id$
#
######################################################################

######################################################################
#
# Configuration
#
echo_commands=0
exit_on_error=1
run_gram_tests=1
run_gridftp_tests=1
run_mds_tests=1

######################################################################
#
# Subroutines
#

usage() {
  cat <<EOF
Usage: $0 [<options>] <target host>

Options are:
  -e      Don't exit on error.
  -F      Skip GridFTP tests
  -G      Skip GRAM tests
  -h      Print this help and exit
  -M      Skip MDS tests
  -x      Echo commands.

EOF
}

######################################################################
#
# Executables
#

globusrun="globusrun"
globus_job_run="globus-job-run"
globus_job_submit="globus-job-submit"
globus_job_status="globus-job-status"
globus_job_get_output="globus-job-get-output"
globus_url_copy="globus-url-copy"
grid_info_search="grid-info-search"
grid_proxy_info="grid-proxy-info"

diff="diff"
rm="rm"
sed="sed"
date="/bin/date"

######################################################################
#
# Main code
#

echo "$0 $Id$ starting"

######################################################################
#
# Parse commandline
#

while getopts eFGhMx arg
do
  case $arg in
  e)
    echo "Will continue on error."
    exit_on_error=0
    ;;
  F)
    echo "Skipping GridFTP tests."
    run_gridftp_tests=0
    ;;
  G)
    echo "Skipping GRAM tests."
    run_gram_tests=0
    ;;
  h)
    usage
    exit 0
    ;;
  M)
    echo "Skipping MDS tests."
    run_mds_tests=0
    ;;
  x)
    echo "Will echo commands."
    echo_commands=1
    ;;
  esac
done

if [ $OPTIND -gt 1 ]; then
  shift `expr $OPTIND - 1`
fi

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

target=$1
shift

######################################################################
#
# Set up
#

# Exit on error
if [ $exit_on_error -eq 1 ]; then
  set -e
fi

# Echo commands
if [ $echo_commands -eq 1 ]; then
  set -x
fi

######################################################################
#
# Make sure we have a valid proxy
#

echo "Making sure you have valid proxy credentials..."
if $grid_proxy_info -exists ; then
  echo "Proxy looks good."
else
  echo "No valid proxy credentials found. Exiting."
  exit 1
fi

# Don't need this...
# Get my subject
#echo "Getting subject..."
#my_subject=`$grid-proxy-info -subject | $sed -e "s/\/CN=proxy//g"`
#echo "My subject is \"$my_subject\""

######################################################################
#
# GRAM tests

if [ $run_gram_tests -eq 1 ]; then
  echo "Running GRAM tests:"

  echo "Globusrun authenticate only test..."
  $globusrun -a -r $target

  echo "globus-job-run $date submission..."
  $globus_job_run $target $date

  echo "globus-job-run with staged $date..."
  $globus_job_run $target -stage $date

  echo "globus-job-submit of $date..."
  job_url=`$globus_job_submit $target $date`
  
  if [ $? -eq 0 ]; then
    echo "Job url is $job_url"

    echo "Querying status of submitted job..."
    $globus_job_status $job_url

    echo "Getting output of submitted job..."
    $globus_job_get_output $job_url
  fi
  
  echo "GRAM tests complete."
fi

######################################################################
#
# GridFTP tests
#

if [ $run_gridftp_tests -eq 1 ]; then
  echo "Running GridFTP tests:"

  test_file_1="/tmp/globus-test-$$.1"
  test_file_2="/tmp/globus-test-$$.2"
  test_file_3="/tmp/globus-test-$$.3"

  echo "Creating temporary file..."
  cat > $test_file_1 <<EOF
This is a test file for globus-test.
Test 1 2 3
1 2 3
Test
EOF

  echo "Doing put with globus-url-copy..."
  $globus_url_copy file://$test_file_1 gsiftp://${target}${test_file_2}

  echo "Doing get with globus-url-copy..."
  $globus_url_copy gsiftp://${target}${test_file_2} file://${test_file_3}

  echo "Comparing file put with file gotten..."
  if $diff $test_file_1 $test_file_3 ; then
    echo "Files match."
  else
    echo "ERROR: Files don't match."
    if [ $exit_on_error -eq 1 ]; then
      exit 1
    fi
  fi

  echo "Cleaning up"
  $rm -f $test_file_1 $test_file_2 $test_file_3
  # XXX Need to clean up test_file_2 if on remote system

  echo "GridFTP tests complete."
fi

######################################################################
#
# MDS tests
#

if [ $run_mds_tests -eq 1 ]; then
  echo "Running MDS tests:"

  echo "Doing basic grid-info-search..."
  $grid_info_search -anonymous -L -h $target "(objectclass=MdsComputer)" dn Mds-Os-name

  echo "MDS tests complete."
fi

######################################################################
#
# Done
#

echo "$0 complete."
exit 0

#
# End Code
#
######################################################################
