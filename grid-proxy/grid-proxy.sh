#!/bin/sh
######################################################################
#
# grid-proxy
#
# Set up my environment to use a specific certificate. This script
# is not meant to be run directly, but instead it's output evaluated.
#
# Run perldoc on this file for a man page.
#
# $Id$
#
######################################################################

# Exit on any error
set -e
#set -x

######################################################################

# Binaries and paths
grid_proxy_init="grid-proxy-init"
grid_proxy_info="grid-proxy-info"

######################################################################

# Default grid_proxy_init options
gpi_options=""

######################################################################
#
# Subroutines
#

# get_cert_dir()
#
# Given a certificate name return the directory for that certificate.
#
# Arguments: certificate name
# Returns: echos directory name

get_cert_dir() 
{
  _cert_name=$1; shift
  
  echo ${HOME}/.certificates/${_cert_name}
}

# get_proxy_file()
#
# Given a certificate name return the name of the proxy file to use.
#
# Arguments: certificate name
# Returns: echos get_proxy_file name

get_proxy_file() {
  _cert_name=$1; shift

  echo /tmp/proxy-${LOGNAME}-${_cert_name}
}

# usage
#
# Print usage.

usage() {
  cat 1>&2 <<EOF

Usage: $0 [<options>] <certificate name>

  Options are one of the following:
    -b        Output for Bourne shell
    -c        Output for csh or variant.
    -d        Run grid-proxy-init with '-debug'
    -f        Generate new proxy even if one exists.
    -h        Display usage and exit.
    -v        Run grid-proxy-init with '-verify'

For a full man page run:

perldoc $0

EOF
}

######################################################################
#
# Parse command line arguments
#

shell=""
arg_error=0
force=0

while getopts bcdfhv arg
do
  case $arg in
    b) # Bourne shell
      if [ "${shell}" != "" ]; then
	echo "Cannot specify more than one shell" 1>&2
	arg_error=1
      else
	shell="sh"
      fi;;

    c) # Csh or variant
          if [ "${shell}" != "" ]; then
	echo "Cannot specify more than one shell" 1>&2
	arg_error=1
      else
	shell="csh"
      fi;;

    d) # Run gpi with -debug
        gpi_options=${gpi_options}" -debug"
        ;;

    f) # Force run of grid-proxy-init
	force=1
	;;

    h)  usage
	exit 0
	;;

    v) # Run gpi with -verify
        gpi_options=${gpi_options}" -verify"
        ;;


  esac
done

if [ $OPTIND -gt 1 ]; then
  shift `expr $OPTIND - 1`
fi

if [ $# -gt 0 ]; then
  cert_name=$1; shift
else
  cert_name=""
fi

######################################################################
#
# Main code
#

# if shell not specified use csh as default
if [ -z "$shell" ]; then
  shell=csh
fi

# If no certificate name specified on command line, look
# for default in GRID_PROXY_CERT_NAME environment variable
if [ -z "${cert_name}" ]; then
  if [ -n "${GRID_PROXY_CERT_NAME}" ]; then
    cert_name="${GRID_PROXY_CERT_NAME}"
  fi
fi

# If we still don't know the certname, we're out of luck
if [ -z "${cert_name}" ]; then
    echo "No certificate name given on command line and no default known" 1>&2
    exit 1
fi

# Set up for specific certificate
echo "Using proxy for certificate \"${cert_name}\"" 1>&2

# Get paths for this certificate

cert_dir=`get_cert_dir ${cert_name}`
proxy_file=`get_proxy_file ${cert_name}`

# Make sure this certificate exists
if [ ! -d ${cert_dir} ]; then
  echo "No certificate named ${cert_name}: ${cert_dir} does not exist" 1>&2
  exit 1
fi

# Set up environment for this certificate

X509_USER_CERT=${cert_dir}/usercert.pem ; export X509_USER_CERT
X509_USER_KEY=${cert_dir}/userkey.pem ; export X509_USER_KEY
X509_USER_PROXY=${proxy_file} ; export X509_USER_PROXY

# Now echo environment for evaluation
#
# Don't set X509_USER_KEY and X509_USER_CERT in the user's
# environment as it messes up GSI libraries in GT 2.2
#
# Set GRID_PROXY_CERT_NAME so that if we are called again
# we use it as the default.

case ${shell} in
  sh)
    #echo "X509_USER_CERT=${X509_USER_CERT} ; export X509_USER_CERT ;"
    #echo "X509_USER_KEY=${X509_USER_KEY} ; export X509_USER_KEY ;"
    echo "X509_USER_PROXY=${X509_USER_PROXY} ; export X509_USER_PROXY ;"
    echo "GRID_PROXY_CERT_NAME=${cert_name} ; export GRID_PROXY_CERT_NAME ;"
    ;;

  csh)
    #echo "setenv X509_USER_CERT ${X509_USER_CERT} ;"
    #echo "setenv X509_USER_KEY ${X509_USER_KEY} ;"
    echo "setenv X509_USER_PROXY ${X509_USER_PROXY} ;"
    echo "setenv GRID_PROXY_CERT_NAME ${cert_name} ;"
    ;;

  *)
    echo "Internal error: unknown shell ${shell}" 1>&2
    exit 1
esac

# Check to see if we have a valid proxy

if test ${force} -eq 0 && ${grid_proxy_info} -exists >& /dev/null ; then

  # We have a valid proxy, print time left

  secs_left=`${grid_proxy_info} -timeleft`
  secs=`expr ${secs_left} % 60`
  mins_left=`expr ${secs_left} / 60`
  mins=`expr ${mins_left} % 60`
  hours_left=`expr ${mins_left} / 60`

  echo "Proxy exists. Time left on proxy: ${hours_left}:${mins}" 1>&2

else

  # Don't have valid proxy, get one

  # This output is not to be evaled so write to stderr
 
  ${grid_proxy_init} ${gpi_options} 1>&2

fi


# Success
exit 0

#
# End Code
#
######################################################################
#
# POD documentation
#

=head1 NAME

grid-proxy - Script for managing multiple certificates/proxies

=head1 SYNOPSIS

grid-proxy [E<lt>optionsE<gt>] [E<lt>certificate nameE<gt>]

B<grid-proxy> is a script to help you manage multiple proxies for
multiple certificates. B<grid-proxy> is not meant to be run directly,
it's output is meant to be avaluated. It meant to be used with the
Grid Security Infrastructure which is part of the Globus Metacomputing
Toolkit (http://www.globus.org).

=head1 SETUP

In order to use grid-proxy you need to perform the following
steps.

1) In your home directory create a directory called .certificates.

2) For each certificate create a directory in this directory with
the name E<lt>nameE<gt> which is an arbitrary
name of your choosing that you wish to use for that certificate. For
example I have the directories F<~/.certificates/globus> for my globus
certificate and F<~/.certificates/ncsa> for my alliance certificate. In each
of these directories you should put the files F<usercert.pam> and
F<userkey.pem> associated with that certificate (these files are normally
found in the F<~/.globus> directory).

3) Install F<grid-proxy> in your path somewhere.

4) The executables F<grid-proxy-init> and F<grid-proxy-info> also need
to be in your path. These are part of the Grid Security Infrastructure
which is part of the Globus Metacomputing Toolkit
(http://www.globus.org).

5) You don't run F<grid-proxy> directly, instead you run it and
evaluate it's output.

For B<csh> (and variants) I suggest you create an alias like
the following:

alias gpi 'eval `grid-proxy !*`'

You probably also want to add the above line to your .cshrc file so
it's persistant.

For B<bash>, create a function like the following in your .bashrc:

gpi()
{
  if [ $# -gt 0 ] ; then
    _gpi_args="$@"
  fi

  eval $(grid-proxy -b $_gpi_args)
}

=head1 USAGE

To use grid-proxy you use the gpi alias or function you set up. Type
"gpi E<lt>nameE<gt>" where E<lt>nameE<gt> is the E<lt>nameE<gt>
portion of the directory you created during setup.

For example I have my DOE Grids certificate in F<~/.certificates/doe>, to
create and use an proxy from my DOE Grids certificate I would run "gpi
doe". This will set all the needed environment variables and run
grid-proxy-init for me if I don't currently have a valid proxy for my
DOE Grids certificate. I can then use "gpi globus" to create a globus
certificate and then use "gpi doe" and "gpi globus" to switch back
and forth between the two proxies. Each time I switch grid-proxy
checks for a valid proxy and runs grid-proxy-init for me if one is not
present.

If you type "gpi" without a name argument, grid-proxy will check to
see if you have a valid proxy for whatever certificate you last
selected. If not it will run grid-proxy-init for you.

=head1 OPTIONS

Commandline options are:

=over 4

=item -b Bourne shell mode

=item -c Csh mode (default)

=item -f Generate new proxy even if one exists.

=item -h Print usage and exit

=back

=head1 AUTHOR

Von Welch welch@mcs.anl.gov

This is free software. You may do with it what you please.  No support
or warrantly given or implied. Bug fixes or comments welcome.

=head1 ACKNOWLEDGMENTS

Tom Goodale (goodale@aei-potsdam.mpg.de) for a bunch of bug fixes and
bash directions.

=cut

