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
# Determine MacOSX version

OSX_VERSION=$(sw_vers | grep ProductVersion | cut -f 2)

######################################################################
#
# Install functions


install_homebrew() {
  # http://brew.sh
  ${RUBY} -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go)"
  ${BREW} doctor
}

install_default() {
  # Install all the stuff normally want
  install_brew_upgrade
  install_tmux
  install_python
  install_ipython
  install_ipython_notebook
  install_macvim  # After python
  install_keychain
  install_password_store
  install_git
  install_wget
  install_markdown
} 

install_macvim() {
  # Overrides older version that comes with MacOSX
  ${BREW} install macvim --override-system-vim
  # TODO: Implement the following
  echo "Fixing python linkage"
  # See https://bugs.launchpad.net/ultisnips/+bug/1178439
  PYTHON_MAJOR=$(python -c 'import sys;print sys.version_info[0]')
  PYTHON_MINOR=$(python -c 'import sys;print sys.version_info[1]')
  PYTHON_MICRO=$(python -c 'import sys;print sys.version_info[2]')
  PYTHON_FULL=${PYTHON_MAJOR}.${PYTHON_MINOR}.${PYTHON_MICRO}
  PYTHON_MM=${PYTHON_MAJOR}.${PYTHON_MINOR}
  # TODO: Find macvim more reliably
  cd /usr/local/Cellar/macvim/*/MacVim.app/Contents/MacOS/
  install_name_tool -change /System/Library/Frameworks/Python.framework/Versions/${PYTHON_MM}/Python /usr/local/Cellar/python/${PYTHON_FULL}/Frameworks/Python.framework/Versions/${PYTHON_MM}/Python MacVim
  install_name_tool -change /System/Library/Frameworks/Python.framework/Versions/${PYTHON_MM}/Python /usr/local/Cellar/python/${PYTHON_FULL}/Frameworks/Python.framework/Versions/${PYTHON_MM}/Python Vim
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
  ${BREW} install swig
}

install_ipython() {
  ${PIP} install ipython readline
}

# http://ipython.org/ipython-doc/stable/interactive/notebook.html
install_ipython_notebook() {
  install_ipython
  ${PIP} install pyzmq
  ${PIP} install tornado
  ${PIP} install Jinja2
}

install_keychain() {
  ${BREW} install keychain
}

install_password_store() {
  ${BREW} install pass
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
  install_gpg2
}

install_gpg2() {
  # Should also install gpg-agent
  ${BREW} install gpg2
  echo "Also install https://gpgtools.org/ for Apple mail interface."
}

install_xcode() {
  case $OSX_VERSION in 
    10.9.*)
      # Kudos: http://www.computersnyou.com/2025/2013/06/install-command-line-tools-in-osx-10-9-mavericks-how-to/
      echo "Trying to update xcode"
      xcode-select --install
      if test $? -eq 0 ; then
        echo "Apparent success, follow directions in dialog."
      else
        echo "Failed."
      fi
      ;;

    10.6.*)
      echo "XCode for Snow Leopard is at: https://connect.apple.com/cgi-bin/WebObjects/MemberSite.woa/wa/getSoftware?bundleID=20792"
      ;;

    *)
      echo "To install Xcode, visit https://developer.apple.com/xcode/"
      echo "Note that it is a large download (1.5GB+)."
      echo "To install command line tools: See Preferences/Downloads as described at http://stackoverflow.com/a/9329325"
      ;;
  esac
}

install_brew_upgrade() {
  ${BREW} update
  ${BREW} upgrade
}

######################################################################

if test $# -eq 0 ; then
    echo "Usage: $0 <install targets>"
    exit 0
fi

for target in $* ; do
    if test ${target} == "help" ; then
        echo "Commands:"
        typeset -F | cut -d " " -f 3 | grep install_ | sed -e "s/^install_/  /"
    else
        install_${target}
    fi
done

exit 0

