#!/bin/sh
######################################################################
#
# Make a meaningless CA that abides by:
# http://tools.ietf.org/html/draft-moreau-pkix-aixcm-00
#
######################################################################

# Exit on any error
set -e

. include.sh

######################################################################
#
# Defaults
#

COUNTRY_NAME="AA"
ORG_NAME="The dummy name X refers to the openly insecure public key ..."
OU_NAME="... of a nominal CA devoid of objective PKI CA characteristics."
ca_name="X"

######################################################################
#
# Parse commandline options
#

usage() {
cat <<EOF
Usage: $0 [<options>] <CA name>

Options:
  -h                   Print help and exit.
  -p <pki path>        Set path for PKI files [default: ${PKI_PATH}]
EOF
}

while getopts hp: arg
do
  case $arg in
  h) usage ; exit 0 ;;
  p) PKI_PATH=$OPTARG ;;
  ?)
    echo "Unknown option: -$ARG"
    usage
    exit 1
  esac
done

shift `expr $OPTIND - 1`

if [ $# -gt 0 ]; then
  echo "Ignoring extra arguments."
fi

######################################################################
#
# Create CA directory
#

if [ ! -d $PKI_PATH ]; then
    echo "Creating ${PKI_PATH}"
    mkdir -p $PKI_PATH
fi

ca_dir=${PKI_PATH}/CA/${ca_name}

if [ -e $ca_dir ]; then
  echo "CA directory $ca_dir already exists."
  exit 1;
fi

echo "Creating CA directory $ca_dir and contents"
mkdir -p $ca_dir
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
sed_script=${sed_script}"s|Xdir|${ca_dir}|g;"
sed_script=${sed_script}"s|Xca_name|${ca_name}|g;"
sed_script=${sed_script}"s|Xca_key|${ca_key}|g;"
sed_script=${sed_script}"s|Xstate_name|${STATE_NAME}|g;"
sed_script=${sed_script}"s|Xcountry_name|${COUNTRY_NAME}|g;"
sed_script=${sed_script}"s|Xemail_addr|${EMAIL_ADDR}|g;"
sed_script=${sed_script}"s|Xorg_name|${ORG_NAME}|g;"
sed_script=${sed_script}"s|Xou_name|${OU_NAME}|g;"

sed "$sed_script" ca.cnf.in > $ca_config

######################################################################
#
# Generate the key and cert
#

echo "Generating CA certificate"

# These variables are used in CA configuration
COMMON_NAME=${ca_name}
export COMMON_NAME
export OU_NAME

cat > ${ca_key} <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQDH3cqnjWsH1/LFe5tf1n+d4hdGc/kCqc0IPOZV8qUrzFJjHe31
dAnSyIgOARpG5kKSfYiV6eniMY1xiNGJ3tOdjheYjws+00dTFiAUMt77CkqfZzTQ
/L257TiPN82eoFcbCg89/H2EtwdRdIeKCoWnavfijPsEoSNbChYftm9vVQIDAQAB
AoGAeZsOCcI2xA/1a4jYsYguH58HsFsxwBgWYxPCxbqcGrj3y8zTEwwmSfSvK24q
UccZ7E2rBCPNpU2nFNQ9QditAdWk/au8rdHkPCUuTdhWnz9v4aMbLKcqenq/NTnv
reT1bz15NkSQGdsogogM50xsndT+xxrgHPQPvMBh5bixLuUCQQDpZIXcSXroqgG6
+lOmigyRXDPHB1IEgBJcxhiNEQ7oIP+j5SrhH0SYTf4ECTTnuhGChsPyjtqAvIgd
3YwmdWb3AkEA2znpXh50X+ihnfOmWaYXF3yeLwtp1SkoVh9zyjILEGvAdaCcI18i
PUf0vw82PY+ggOoZO1pTBXB7G7z2v6PNEwJBAIxFGh6XGwOSiY+yu2uwNHV4kLXh
tG13+5E+jarawbbJflsmdGrwu+09kpkiX2WV8sgb7tBtAu20YapxaLYEgWkCQAFN
+OuMdtjTQ5LzDjxeVqjXHwHcqYaRNiI9Ea1UWuiAG6cXi5ZSTJvcv8IbTxFSt3vM
6NWHlhLkNndVyoodaW0CQQCmMnn5UOhQ6SvvXvPUUjDY1bcqs5S8WvZqPO+VUQoX
1Zjc7TkTkphjuTMO3dMahX2B++xn7TfX1u2nvGy9OVEe
-----END RSA PRIVATE KEY-----
EOF

${openssl} req -x509 -new \
  -key ${ca_key} \
  -out ${ca_cert} \
  -days $lifetime \
  -config $ca_config \
  -nodes

rm -f ${keyFile}

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


