#!/bin/sh
######################################################################
#
# Make a new user certificate
#
######################################################################

# Exit on any error
set -e

. include.sh

target_dir="."

######################################################################
#
# Parse commandline options
#

usage() {
cat <<EOF
Usage: $0 [<options>] <CA name> <common name>

Options:
 -d <target directory>   Where to put certificates [default: ${target_dir}]
 -h                      Print help and exit.
 -p <pki path>           Set path for PKI files [default: ${PKI_PATH}]
EOF
}

while getopts d:hp: arg
do
  case $arg in
  d) target_dir=$OPTARG ;;
  h) usage ; exit 0 ;;
  p) PKI_PATH=$OPTARG ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -lt 1 ]; then
  echo "CA name required."
  usage
  exit 1
fi

ca_name=$1
shift

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

ca_dir=${PKI_PATH}/CA/${ca_name}

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

# Make sure key file is the right permission
touch ${target_dir}/key.pem
chmod 600 ${target_dir}/key.pem

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


