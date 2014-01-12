#!/bin/bash
#
# Install python, helper utilities and frequently used modules

######################################################################
#
# Constants

PIP=pip

######################################################################
#
# Get OS name

uname=$(uname)

######################################################################
#
# Functons

install_module() {
  for module in $* ; do
    echo "Installing module ${module}"
    ${PIP} install ${module} || exit 1
  done
}

######################################################################
#
# Start by doing OS-specific python, pip and swig install

echo "Installing python"
case ${uname} in
  Darwin)
    brew install python
    # Above installs pip
    ;;

  *)
    echo "Don't know how to install python on ${uname}"
    exit 1
    ;;
esac

echo "Installing pip"

case ${uname} in
  Darwin)
    # XXX Should already be installed
    ;;

  *)
    echo "Don't know how to install pip on ${uname}"
    exit 1
    ;;
esac

echo "Installing swig"

case ${uname} in
  Darwin)
    brew install swig
    ;;

  *)
    echo "Don't know how to install swig on ${uname}"
    exit 1
    ;;
esac

######################################################################

echo "Installing virtualenv and virtualenvwrapper"
install_module virtualenv virtualenvwrapper

######################################################################
#
# Installing ipython and notebook

echo "Installing iPython"
install_module ipython readline

echo "Install iPython Notebook"

# http://ipython.org/ipython-doc/stable/interactive/notebook.html
install_module pyzmq tornado Jinja2

######################################################################

echo "Installing frequently used modules"

# Graphical debugger
# https://pypi.python.org/pypi/pudb
install_module pudb

# Subprocess interace
# http://amoffat.github.io/sh/
install_module sh

# Contexter - a better contextlib
# https://bitbucket.org/defnull/contexter
install_module contexter

# docopt - commandline interface description language
# http://docopt.org/
install_module docopt

# mock - mocking and testing library
# http://www.voidspace.org.uk/python/mock/
install_module mock

# requests - HTTP for humans
# http://www.python-requests.org/
install_module requests

######################################################################

echo "Success."
exit 0
