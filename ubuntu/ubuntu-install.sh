#!/bin/sh
#
# Install various stuff on ubuntu.

# Exit on any error
set -e

SUDO="sudo"
APT_GET="${SUDO} apt-get"
INSTALL="${APT_GET} install"

. /etc/lsb-release

install_update()
{
    ${APT_GET} update
    ${APT_GET} upgrade
}

install_basics()
{
    local BASICS="\
	subversion git cvs vim \
	build-essential \
	openssh-client \
	secure-delete \
	"
    ${INSTALL} ${BASICS}
}

install_homestuff()
{
    git clone http://git@www.vwelch.com/GIT/homestuff.git
}

install_server()
{
    local SERVER_STUFF="\
	logwatch \
	screen tmux \
	openssh-server \
	"
    ${INSTALL} {$SERVER_STUFF}
}

install_guis()
{
    local GUI_INSTALLS="\
	emacs \
	keepassx \
	"
    ${INSTALL} ${GUI_INSTALLS}
}

# Kudos: http://www.gaggl.com/2011/05/install-handbrake-on-ubuntu-11-04-natty/
install_handbrake()
{
    ${INSTALL} ubuntu-restricted-extras
    ${SUDO} /usr/share/doc/libdvdread4/install-css.sh
    ${SUDO} add-apt-repository ppa:stebbins/handbrake-releases
    ${APT_GET} update
    ${INSTALL} handbrake-gtk handbrake-cli
}

# Kudos: http://www.liberiangeek.net/2011/12/install-google-chrome-using-apt-get-in-ubuntu-11-10-oneiric-ocelot
install_chrome()
{
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | ${SUDO} apt-key add -
    echo "deb http://dl.google.com/linux/chrome/deb/ stable main" | ${SUDO} tee --append /etc/apt/sources.list.d/google.list
    ${APT_GET} update
    ${INSTALL} google-chrome-stable
}

# Kudos: http://www.andydixon.com/2012/01/12/installing-and-configuring-spideroak-headless/
install_spideroak()
{
    wget -O /tmp/spideroak.deb "https://spideroak.com/directdownload?platform=ubuntulucid&arch=i386"
    ${SUDO} dpkg -i /tmp/spideroak.deb
}

install_dropbox()
{
    wget -O /tmp/dropbox.deb "https://www.dropbox.com/download?dl=packages/ubuntu/nautilus-dropbox_0.7.1_i386.deb"
    ${SUDO} dpkg -i /tmp/dropbox.deb
}

install_virtualbox()
{
    echo "deb http://download.virtualbox.org/virtualbox/debian ${DISTRIB_CODENAME} contrib" | ${SUDO} tee --append /etc/apt/sources.list
    wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | ${SUDO} apt-key add -
    ${SUDO} ${APT_GET} update
    ${INSTALL} virtualbox-4.1
}

install_freemind()
{
    ${SUDO} ${APT_GET} -f install libcommons-lang-java libjgoodies-forms-java libjibx-java simplyhtml
    wget -O /tmp/freemind.deb "http://launchpadlibrarian.net/37381563/freemind_0.9.0~rc6%2Bdfsg-1ubuntu1_all.deb"
    ${SUDO} dpkg -i /tmp/freemind.deb
}

install_abcde()
{
    ${SUDO} ${APT_GET} install abcde lame id3v2
}

install_eyeD3()
{
    ${SUDO} ${APT_GET} install eyed3 python-eyed3
}

if test $# -eq 0 ; then
    echo "Usage: $0 <install targets>"
    exit 0
fi

for target in $* ; do
    install_${target}
done

