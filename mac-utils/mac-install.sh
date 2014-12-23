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
# Helper functions

brew_installed() {
  # Return 0 if forumula installed, 1 otherwise
  # Arguments: forumula
  _formula=${1}
  ${BREW} list ${_formula} >/dev/null 2>&1 && return 0
  return 1
}

brew_install() {
  # Install formula if not already installed
  # Arguments: forumla [<options>]
  _formula=$1
  brew_installed ${_formula} && \
    { echo "${_formula} already installed." ; return ; }
  ${BREW} install ${_formula} "${@}"
}

cask_installed() {
  # Return 0 if cask forumula installed, 1 otherwise
  # Arguments: forumula
  _formula=${1}
  ${BREW} cask list ${_formula} >/dev/null 2>&1 && return 0
  return 1
}

cask_install() {
  # Install cask formula if not already installed
  # Arguments: forumla [<options>]
  _formula=$1
  cask_installed ${_formula} && \
    { echo "${_formula} already installed." ; return ; }
  ${BREW} cask install ${_formula} "${@}"
}

######################################################################
#
# Install functions

install_homebrew() {
  # http://brew.sh
  ${RUBY} -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
  ${BREW} doctor
}

install_cask() {
  # http://caskroom.io/
  brew_install caskroom/cask/brew-cask
}

install_default() {
  # Install all the stuff normally want
  install_brew_upgrade
  install_cask
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
  install_ctags
  install_jrnl
  install_mr
  install_moreutils
  install_vifm
} 

install_macvim() {
  # Overrides older version that comes with MacOSX
  if brew_installed macvim ; then
    echo "macvim already installed"
    return 0
  fi
  brew_install macvim --override-system-vim
  echo "MacVim installed."
  echo "Note you may need to rebuild YouCompleteMe to pick up new python"
  echo "  libraries."
}

install_tmux() {
  brew_install tmux
  # https://github.com/ChrisJohnsen/tmux-MacOSX-pasteboard
  brew_install reattach-to-user-namespace --wrap-pbcopy-and-pbpaste
}

install_aquamacs() {
  echo "Install AquaMacs from http://aquamacs.org/"
  echo "Then Commandline tools from Tools->Install Command Line Tools"
  echo "  (See http://www.emacswiki.org/emacs/AquamacsFAQ#toc23)"
}

install_python() {
  brew_install python  # Also installs pip
  # Graphical debugger: https://pypi.python.org/pypi/pudb
  ${PIP} install pudb
  ${PIP} install virtualenv
  ${PIP} install virtualenvwrapper
  brew_install swig
}

install_python3() {
  brew_install python3  # Also installs pip3
  pip3 install --upgrade pip
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
  brew_install keychain
}

install_password_store() {
  #echo "Install my version from git@von-forks.github.com:von-forks/password-store.git"
  brew_install pass
}

install_git() {
  brew_install git
  # tig is curses UI to git: http://jonas.nitro.dk/tig/
  brew_install tig
}

install_wget() {
  brew_install wget
}

install_markdown() {
  brew_install markdown
}

install_ctags() {
  # ctags.sourceforge.net
  # Needed for majutsushi/tagbar in vim
  brew install ctags-exuberant
}
install_gpg() {
  install_gpg2
}

install_gpg2() {
  # Should also install gpg-agent
  brew_install gpg2
  echo "Also install https://gpgtools.org/ for Apple mail interface."
}

install_jrnl() {
  # http://maebert.github.io/jrnl/
  brew_install jrnl
}

install_mr() {
  # http://myrepos.branchable.com/
  brew_install mr
}

install_moreutils() {
  # https://joeyh.name/code/moreutils/
  brew_install moreutils
}

install_vifm() {
  # Curses-based file manager with vi-like keybindings
  # http://vifm.info/
  brew_install vifm
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

    10.10.*)
      echo "Install XCode using App Store"
      ;;

    *)
      echo "To install Xcode, visit https://developer.apple.com/xcode/"
      echo "Note that it is a large download (1.5GB+)."
      echo "To install command line tools: See Preferences/Downloads as described at http://stackoverflow.com/a/9329325"
      ;;
  esac
}

######################################################################
#
# Cask-installed apps
#

install_apps() {
  install_chrome
  install_google_drive
  install_skype
  install_dropbox
  install_android_file_transfer
  install_totalfinder
  install_firefox
}

install_chrome() {
  cask_install google-chrome
}

install_google_drive() {
  cask_install google-drive
}

install_skype() {
  cask_install skype
}

install_dropbox() {
  cask_install dropbox
}

install_android_file_transfer() {
  cask_install android-file-transfer
}

install_totalfinder() {
  cask_install totalfinder
}

install_wesnoth() {
  #cask_install wesnoth
  echo "Cask for Battle of Wesnoth is out of date, download from website."
}

install_firefox() {
  cask_install firefox
}

######################################################################

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

