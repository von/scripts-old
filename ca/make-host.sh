#!/bin/sh
######################################################################
#
# Make a new host certificate
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
Usage: $0 [<options>] <host name>

Options:
 -c <ca name>            Name of issuing CA ("default" by default).
 -h                      Print help and exit.
EOF
}

ca_name="default"

while getopts c: arg
do
  case $arg in
  c) # CA name
    ca_name=$OPTARG ;;
  h) usage ; exit 0 ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -lt 1 ]; then
  echo "Host name required."
  usage
  exit 1
fi

host_name=$1
shift

######################################################################
#
# Create host directory
#

if [ ! -d host ]; then
  mkdir host
fi

host_dir="host/${host_name}"

if [ -e $host_dir ]; then
  echo "Host directory $host_dir already exists."
  exit 1;
fi

echo "Creating host directory $host_dir"


mkdir $host_dir

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

COMMON_NAME="host/"${host_name}
export COMMON_NAME
OU_NAME="Host"
export OU_NAME

${openssl} req \
  -new \
  -out $host_dir/req.pem \
  -keyout $host_dir/hostkey.pem \
  -config $ca_config \
  -nodes

echo "Setting permissions on private key"
chmod 600 $host_dir/hostkey.pem

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
  -in ${host_dir}/req.pem \
  -out ${host_dir}/hostcert.pem

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


