#!/bin/sh
set -e
set -x
rm -rf test-ca
./make-ca.sh test-ca Test-CA
rm -rf test-sub-ca
./make-sub.sh -c test-ca test-sub-ca Test-Sub-CA
rm -rf test-user
./make-user.sh -c test-sub-ca test-user
./make-crl.sh default

