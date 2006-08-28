#!/bin/sh
######################################################################
#
# Make a new user certificate
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
Usage: $0 [<options>] <common name>

Options:
 -c <ca directory>       Path for CA directory.
 -d <target directory>   Where to put certificates.
 -h                      Print help and exit.
EOF
}

target_dir="."
ca_dir="."

while getopts c:d:h arg
do
  case $arg in
  c) # CA directory
    ca_dir=$OPTARG ;;
  d) target_dir=$OPTARG ;;
  h) usage ; exit 0 ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -lt 1 ]; then
  echo "Common name required."
  usage
  exit 1
fi

common_name=$1
shift

######################################################################
#
# Validate target directory
#

if [ ! -d $target_dir ]; then
  echo "Target directory $target_dir does not exist."
fi

######################################################################
#
# Find the ca
#

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
# Generate the req
#

echo "Generating the request"

COMMON_NAME=${common_name}
export COMMON_NAME

OU_NAME="User"
export OU_NAME

${openssl} req \
  -new \
  -out ${target_dir}/req.pem \
  -keyout ${target_dir}/key.pem \
  -config $ca_config \
  -nodes

######################################################################
#
# Ok now sign the req
#

echo "Signing the request"

${openssl} ca \
  -batch \
  -config $ca_config \
  -name $ca_name \
  -preserveDN \
  -in ${target_dir}/req.pem \
  -out ${target_dir}/cert.pem

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


