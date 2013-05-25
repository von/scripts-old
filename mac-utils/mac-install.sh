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
  # TODO: Implement the following
  # Fix python linkage, see https://bugs.launchpad.net/ultisnips/+bug/1178439
  # cd /usr/local/Cellar/macvim/7.3-66/MacVim.app/Contents/MacOS/
  # install_name_tool -change /System/Library/Frameworks/Python.framework/Versions/2.7/Python /usr/local/Cellar/python/2.7.5/Frameworks/Python.framework/Versions/2.7/Python MacVim
  # install_name_tool -change /System/Library/Frameworks/Python.framework/Versions/2.7/Python /usr/local/Cellar/python/2.7.5/Frameworks/Python.framework/Versions/2.7/Python Vim
}

install_tmux() {
  ${BREW} install tmux
  # https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
  ${BREW} install reattach-to-user-namespace --wrap-pbcopy-and-pbpaste
}

install_aquamacs() {
  echo "Install AquaMacs from http://aquamacs.org/"
  echo "Then Commandline tools from Tools->Install Command Line Tools"
  echo "  (See http://www.emacswiki.org/emacs/AquamacsFAQ#toc23)"
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
  # tig is curses UI to git: http://jonas.nitro.dk/tig/
  ${BREW} install tig
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

install_xcode() {
  echo "To install Xcode, visit https://developer.apple.com/xcode/"
  echo "Note that it is a large download (1.5GB+)."
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

