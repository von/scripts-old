#!/bin/sh
#
# Create a branch in the local git report tracking a remote repo

set -e  # Exit on error
set -u  # Exit on undefined variable use

usage() {
  echo "Usage: $0 <branch name> <remote url>"
}

if test $# -ne 0 ; then
    usage
    exit 1
fi

BRANCH=$1; shift
REMOTE_URL=$1; shift
REMOTE_BRANCH="master"  # TODO: Allow override

echo "Creating branch ${BRANCH} tracking ${REMOTE_URL}"

# Current assumptions:
#  $BRANCH does not exist
#  $REMOTE_URL is valid and is not current remote in local repo

git remote add ${BRANCH} ${REMOTE_URL}
git checkout -b ${BRANCH}
git fetch ${BRANCH}
git bracnh --set-upstream-to ${BRANCH} ${BRANCH}/${REMOTE_BRANCH}
git pull

echo "Success."
exit 0
