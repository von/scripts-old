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
  echo "Usage: $0 <ca name> <user name>"
}

ca_name="default"

while getopts c: arg
do
  case $arg in
  c) # CA name
    ca_name=$OPTARG ;;
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
# Create user directory
#

if [ ! -d user ]; then
  mkdir user
fi

user_dir="user/${user_name}"

if [ -e $user_dir ]; then
  echo "User directory $user_dir already exists."
  exit 1;
fi

echo "Creating user directory $user_dir"


mkdir $user_dir

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
# Generate the req
#

echo "Generating the request"

COMMON_NAME=${user_name}
OU_NAME="User"

${openssl} req \
  -new \
  -out $user_dir/req.pem \
  -keyout $user_dir/key.pem \
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
  -in ${user_dir}/req.pem \
  -out ${user_dir}/cert.pem

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


