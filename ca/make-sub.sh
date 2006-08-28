#!/bin/sh
######################################################################
#
# Make a subordinate CA.
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
Usage: $0 [<options>] <subordinate CA path> <subordinate CA name>

Options:
  -c <ca path>         Path of superior CA
  -h                   Print help and exit.
EOF
}

target_dir="."
ca_dir="."

while getopts c:h arg
do
  case $arg in
  c) # Superior CA path
    ca_dir=$OPTARG ;;
  h) usage; exit 0 ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -gt 0 ]; then
  target_dir=$1
  shift
else
  echo "Missing CA directory argument"
  usage
  exit 1
fi

if [ $# -gt 0 ]; then
  ca_name=$1
  shift
else
  echo "Missing CA name argument"
  usage
  exit 1
fi

######################################################################
#
# Find superior CA
#

if [ ! -d $ca_dir ]; then
  echo "Can't find superior CA: $ca_dir does not exist."
  exit 1
fi

top_ca_config=${ca_dir}/ca.cnf

if [ ! -e $top_ca_config ]; then
  echo "Can't find configuration file for superior CA: $top_ca_config"
  exit 1
fi

######################################################################
#
# Create target CA directory
#

if [ -e $target_dir ]; then
  echo "CA directory $ca_dir already exists."
  exit 1;
fi

echo "Creating CA directory $target_dir and contents"
mkdir $target_dir
mkdir ${target_dir}/certs
touch ${target_dir}/index.txt
echo "01" > ${target_dir}/serial

######################################################################
#
# Copy in configuration file
#

echo "Creating CA configuration"

ca_config=$target_dir/ca.cnf
ca_key=$target_dir/key.pem
ca_cert=$target_dir/cert.pem
pwd=`pwd`

sed_script=""
sed_script=${sed_script}"s|Xdir|${target_dir}|g;"
sed_script=${sed_script}"s|Xca_name|${ca_name}|g;"
sed_script=${sed_script}"s|Xca_key|${ca_key}|g;"

echo $sed_script

sed $sed_script ca.cnf.in > $ca_config

######################################################################
#
# Generate the req
#

echo "Generating subordinate CA certificate request"

# These variables are used in CA configuration
COMMON_NAME=${ca_name}
export COMMON_NAME
OU_NAME="Subordinate CA"
export OU_NAME

ca_req=${ca_dir}/req.pem

${openssl} req \
  -new \
  -out ${ca_req} \
  -keyout ${ca_key} \
  -days $lifetime \
  -config $top_ca_config \
  -nodes

######################################################################
#
# Now sign the req
#

echo "Signing subordinate CA certificate"

${openssl} ca \
  -config $top_ca_config \
  -preserveDN \
  -extensions sub_ca_extensions \
  -batch \
  -in $ca_req \
  -out $ca_cert

######################################################################
#
# Ok generate the Globus-specific stuff. First ca cert file.
#

echo "Generating Globus-specific stuff"

ca_hash=`${openssl} x509 -in $ca_cert -hash -noout`

cp ${ca_cert} ${target_dir}/${ca_hash}.0

ca_signing_policy=${target_dir}/${ca_hash}.signing_policy
dn="/C=${COUNTRY_NAME}/O=${ORG_NAME}/OU=${OU_NAME}/CN=${COMMON_NAME}"
namespace="/C=${COUNTRY_NAME}/O=${ORG_NAME}/*"

sed_script=""
sed_script="${sed_script}s|Xdn|${dn}|g;"
sed_script="${sed_script}s|Xnamespace|${namespace}|g;"

sed "${sed_script}" signing_policy.in > $ca_signing_policy

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


