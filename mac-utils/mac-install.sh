#!/bin/sh
#
# Install various stuff on MacOSX

# Exit on any error
set -e

# An unset variable is an error
set -u

######################################################################
#
# Binaries

BREW="brew"
PIP="pip"
RUBY="ruby"
SUDO="sudo"

######################################################################
#
# Install functions


install_homebrew() {
    # http://mxcl.github.com/homebrew/
    ${RUBY} -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"
}

install_macvim() {
    # Overrides older version that comes with MacOSX
    ${BREW} install macvim --override-system-vim
}

install_tmux() {
    ${BREW} install tmux
    # https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
    ${BREW} install reattach-to-user-namespace --wrap-pbcopy-and-pbpaste
}

install_aquamacs() {
# http://aquamacs.org/
# http://www.emacswiki.org/emacs/AquamacsFAQ#toc23
# Tools->Install Command Line Tools
}

install_python() {
    ${BREW} install python  # Also installs pip
    ${PIP} install virtualenv
    ${PIP} install virtualenvwrapper
    ${PIP} install swig-python
}

install_ipython() {
    ${PIP} install ipython readline
}


install_keychain() {
    ${BREW} install keychain
}

install_password_store() {
    ${BREW} install password-store
}

install_git() {
    ${BREW} install git
}

install_wget() {
    ${BREW} install wget
}

install_markdown() {
    ${BREW} install markdown
}

install_gpg() {
    ${BREW} install gpg
}


######################################################################

if test $# -eq 0 ; then
    echo "Usage: $0 <install targets>"
    exit 0
fi

for target in $* ; do
    install_${target}
done

exit 0

