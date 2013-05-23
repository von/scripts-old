#!/bin/sh
# Update brew and all brew packages
# Kudos: http://www.commandlinefu.com/commands/view/4831/update-all-packages-installed-via-homebrew

set -e  # Exit on any error
brew update
outdated=$(brew outdated --quiet)
errors=0
for pkg in ${outdated} ; do
  brew upgrade ${pkg} || errors=$(($errors+1))
done
if test ${errors} -gt 0 ; then
  echo "${errors} encountered."
  exit 1
fi
echo "Success."
exit 0

