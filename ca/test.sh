#!/bin/sh
set -e
rm -rf ca/default ca/sub user/test
./make-ca.sh default
./make-sub.sh sub
./make-user.sh -c sub test
./make-crl.sh default

