#!/bin/sh
#set -x
###########################################################################
#
# startx
#
# My scripts to fire off an Xserver
#
# $Id$
#
###########################################################################

XINIT_CMD="xinit"

XAUTH_CMD="xauth"

MCOOKIE_CMD="mcookie"

# Arguments that will be passed to xinit
XINIT_SERVER_OPTS=""
XINIT_CLIENT_OPTS=""

REDIRECT_OUTPUT=1

######################################################################
#
# Parse command line arguments
#

while getopts d:w:R arg
do
  case $arg in
    d) DISPLAY=$OPTARG ;;
    R) REDIRECT_OUTPUT=0 ;;
    w) WINDOW_MANAGER=$OPTARG ;;
  esac
done

shift `expr $OPTIND - 1`

######################################################################
#
# Redirect all output to our log file
#

if [ "$REDIRECT_OUTPUT" -eq 1 ]; then
  X_LOG_FILE=/usr/tmp/xlog.$USER.$$

  export X_LOG_FILE

  echo "Logging to ${X_LOG_FILE}"

  exec > ${X_LOG_FILE} 2>&1

  echo "$0 running"
fi

date

######################################################################
#
# Set all necessary environment veriables
#

if [ -z "$DISPLAY" ]; then
  DISPLAY=":0.0"
fi

export DISPLAY

if [ "$DISPLAY" = ":0.0" ]; then
  DISPLAY_HOST=`hostname`
else
  DISPLAY_HOST=`echo $DISPLAY | cut -d : -f 1`
fi

export DISPLAY_HOST

DISPLAY_NUM=`echo $DISPLAY | cut -d : -f 2`

export DISPLAY_NUM

###########################################################################

# Just so we know where we're at
cd $HOME
 
# Set up our Xauthority
XAUTHORITY_FILE=${XAUTHORITY:-"$HOME/.Xauthority"}
echo "Adding Xauth enteries to ${XAUTHORITY_FILE}"

COOKIE=`${MCOOKIE_CMD}`

$XAUTH_CMD add $DISPLAY . $COOKIE
$XAUTH_CMD add ":"$DISPLAY_NUM . $COOKIE

XINIT_SERVER_OPTS="${XINIT_SERVER_OPTS} -auth $XAUTHORITY_FILE"

# Turn on auditing
#  level 0: no auditing
#  level 1: report rejected connections
#  level 2: report all connections
AUDIT_LEVEL="2"
echo "Turning on auditing at level ${AUDIT_LEVEL}"
XINIT_SERVER_OPTS="${XINIT_SERVER_OPTS} -audit ${AUDIT_LEVEL}"

# Do it
set -x
${XINIT_CMD} ${XINIT_CLIENT_OPTS} -- ${XINIT_SERVER_OPTS}
set +x
echo "Xinit finished"

echo "Cleaning up"

# Should do this for us but we'll make sure...
kbd_mode -a

# Kill the ssh-agent
ssh-agent -k

echo "$0 Done"
exit 0

