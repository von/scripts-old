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
Usage: $0 [<options>] [<ca name>]

CA name will be "default" if not provided.

Options:
  -c <ca name>         Name of superior CA ("default" by default).
  -h                   Print help and exit.
EOF
}

top_ca_name="default"

while getopts c:h arg
do
  case $arg in
  c) # Superior name
    top_ca_name=$OPTARG ;;
  h) usage; exit 0 ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -ne 1 ]; then
  echo "Name of new CA required."
  usage
  exit 1
fi

ca_name=$1
shift

######################################################################
#
# Find superior CA
#

top_ca_dir=ca/$top_ca_name

if [ ! -d $top_ca_dir ]; then
  echo "Can't find superior CA: $top_ca_dir does not exist."
  exit 1
fi

top_ca_config=${top_ca_dir}/ca.cnf

if [ ! -e $top_ca_config ]; then
  echo "Can't find configuration file for superior CA: $top_ca_config"
  exit 1
fi

######################################################################
#
# Create CA directory
#

if [ ! -d ca ]; then
  mkdir ca
fi

ca_dir="ca/${ca_name}"

if [ -e $ca_dir ]; then
  echo "CA directory $ca_dir already exists."
  exit 1;
fi

echo "Creating CA directory $ca_dir and contents"
mkdir $ca_dir
mkdir ${ca_dir}/certs
touch ${ca_dir}/index.txt
echo "01" > $ca_dir/serial

######################################################################
#
# Copy in configuration file
#

echo "Creating CA configuration"

ca_config=$ca_dir/ca.cnf
ca_key=$ca_dir/key.pem
ca_cert=$ca_dir/cert.pem
pwd=`pwd`

sed_script=""
sed_script=${sed_script}"s\\Xdir\\${pwd}/${ca_dir}\\g;"
sed_script=${sed_script}"s\\Xca_name\\${ca_name}\\g;"
sed_script=${sed_script}"s\\Xca_key\\${pwd}/${ca_key}\\g;"

sed $sed_script ca.cnf.in > $ca_config

######################################################################
#
# Generate the req
#

echo "Generating subordinate CA certificate request"

# These variables are used in CA configuration
COMMON_NAME=${ca_name}
OU_NAME="Subordinate CA"

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

cp ${ca_cert} ${ca_dir}/${ca_hash}.0

ca_signing_policy=${ca_dir}/${ca_hash}.signing_policy
dn="/C=${COUNTRY_NAME}/O=${ORG_NAME}/OU=${OU_NAME}/CN=${COMMON_NAME}"
namespace="/C=${COUNTRY_NAME}/O=${ORG_NAME}/*"

sed_script=""
sed_script="${sed_script}s\\Xdn\\${dn}\\g;"
sed_script="${sed_script}s\\Xnamespace\\${namespace}\\g;"

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


