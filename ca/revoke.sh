#!/bin/sh
######################################################################
#
# Revoke a user certificate
#
######################################################################

# Exit on any error
set -e

. include.sh

######################################################################
#
# Parse commandline options
#

usage() {
cat <<EOF
Usage: $0 [<options>] <ca or user name>

Options:
  -c <issuer name>     Name of certificate issuer ("default" by default).
  -C                   Certificate to revoke is CA certificate.
  -h                   Print help and exit.
EOF
}

ca_name="default"
type="user"

while getopts c:Ch arg
do
  case $arg in
  c) # CA name
    ca_name=$OPTARG ;;
  C) # Revoke CA
    type="ca" ;;
  h) usage ; exit 0 ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

user_name=$1
shift

######################################################################
#
# Fine certificate to revoke
#

cert_dir="${type}/${user_name}"

if [ ! -e $cert_dir ]; then
  echo "Directory $cert_dir does not exist."
  exit 1;
fi

cert=${cert_dir}/cert.pem

if [ ! -e $cert ]; then
  echo "Cannout find ${type} certificate: $cert"
  exit 1;
fi

######################################################################
#
# Find the ca
#

ca_dir=ca/${ca_name}

if [ ! -d $ca_dir ]; then
  echo "Unknown ca $ca_name: $ca_dir not found"
  exit 1
fi

ca_config=${ca_dir}/ca.cnf

if [ ! -e $ca_config ]; then
  echo "CA configuration file missing: $ca_config"
  exit 1
fi

######################################################################
#
# Revoke
#

echo "Revoking certificate for $type $user_name"

${openssl} ca \
  -revoke $cert \
  -config $ca_config

######################################################################
#
# Success
#

echo "Success."
exit 0

#
# End
#
######################################################################


