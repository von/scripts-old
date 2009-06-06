#!/bin/sh
#
# Setup routing to a NAT'ed Ubuntu guest via localhost 2222
#
# kudos:
# http://kdl.nobugware.com/post/2009/02/17/virtualbox-nat-ssh-guest/
# http://mydebian.blogdns.org/?p=148

# Exit on any error
set -e

# Interface name in guest.
# This will vary, not sure how to autodetect
iface="pcnet"

# Local port to forard
localPort=2222

if test $# -ne 1; then
    echo "usage: $0 <VM>"
    exit 1
fi

vm=$1
shift

VBoxManage -q setextradata ${vm}  "VBoxInternal/Devices/${iface}/0/LUN#0/Config/ssh/Protocol" TCP
VBoxManage -q setextradata ${vm}  "VBoxInternal/Devices/${iface}/0/LUN#0/Config/ssh/GuestPort" 22
VBoxManage -q setextradata ${vm}  "VBoxInternal/Devices/${iface}/0/LUN#0/Config/ssh/HostPort" ${localPort}

echo "Success:"
VBoxManage -q getextradata ${vm} enumerate
exit 0
