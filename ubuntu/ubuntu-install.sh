#!/bin/sh
#
# Install various stuff on ubuntu.

# Exit on any error
set -e

# An unset variable is an error
set -u

SUDO="sudo"
APT_GET="${SUDO} apt-get"
INSTALL="${APT_GET} install"

. /etc/lsb-release

install_update()
{
    ${APT_GET} update
    ${APT_GET} upgrade
    # Kernel and other updates that might require a reboot
    ${APT_GET} dist-upgrade
}

install_basics()
{
    local BASICS="\
	subversion git cvs vim \
	build-essential \
	openssh-client \
	secure-delete \
        zsh
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
    ${INSTALL} ${SERVER_STUFF}
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

install_tbb()  # Tor browser bundle
{
    # Kudos: http://forum.tinycorelinux.net/index.php/topic,11352.0.html
    local _install_path=/usr/local/tor-browser_en-US
    local _install_version_file=${_install_path}/VERSION
    local _tor_download_url="https://www.torproject.org/projects/torbrowser.html.en"

    if test -e ${_install_version_file} ; then
        local _installed_version=$(cat ${_install_version_file})
        echo "Installed version is ${_installed_version}"
    else
        local _installed_version=""
        echo "No installed version (or can't determine version)"
    fi

    echo -n "Determining latest version of Tor Browser Bundle... "
    local _download_line="$(wget -q --no-check-certificate ${_tor_download_url} -O - | grep tor-browser-gnu-linux-i686- | head -1)"
    local _latest_version=$(expr match "${_download_line}" '.*i686-\(.*\)-dev')
    echo ${_latest_version}

    if test -z "${_latest_version}" ; then
        echo "Failed to determined latest version."
        return 1
    fi

    if test "${_installed_version}" != "${_latest_version}" ; then
        echo "Installed latest version..."
        local _tarball="tor-browser-gnu-linux-i686-${_latest_version}-dev-en-US.tar.gz"
        local _url="https://www.torproject.org/dist/torbrowser/linux/${_tarball}"
        wget -O /tmp/${_tarball} ${_url}
        if test -d ${_install_path} ; then
            sudo rm -rf ${_install_path}
        fi
        (cd /tmp && \
            tar xfz ${_tarball} && \
            sudo mv tor-browser_en-US ${_install_path})
        echo ${_latest_version} > ${_install_version_file}
        echo "Tor browser bundle version ${_latest_version} installed in ${_install_path}"
    else
        echo "Nothing to do."
    fi
}

install_python2_6()
{
    # Kudos: http://askubuntu.com/a/141664
    ${SUDO} add-apt-repository ppa:fkrull/deadsnakes
    ${SUDO} ${APT_GET} update
    ${SUDO} ${APT_GET} install python2.6 python2.6-dev
}

install_python2_4()
{
    # Kudos: http://askubuntu.com/a/141664
    ${SUDO} add-apt-repository ppa:fkrull/deadsnakes
    ${SUDO} ${APT_GET} update
    ${SUDO} ${APT_GET} install python2.4 python2.4-dev
}

install_virtualenv()
{
    # Kudos: http://www.youtube.com/watch?v=ViIAAZ4_-aA&noredirect=1
    ${SUDO} ${APT_GET} python-virtualenv
    pip install virtualenvwrapper
}

install_m2crypto()
{
    # Kudos: http://stackoverflow.com/a/3107169/197789
    ${SUDO} ${APT_GET} install python-dev python-m2crypto
}

# Medibuntu (Multimedia, Entertainment & Distractions In Ubuntu) is a
# repository of packages that cannot be included into the Ubuntu
# distribution for legal reasons (copyright, license, patent, etc).  
# https://help.ubuntu.com/community/Medibuntu
install_medibuntu()
{
  ${SUDO} wget --output-document=/etc/apt/sources.list.d/medibuntu.list \
    http://www.medibuntu.org/sources.list.d/$(lsb_release -cs).list
  ${SUDO} apt-get --quiet update
  ${SUDO} apt-get --yes --quiet --allow-unauthenticated \
    install medibuntu-keyring
  ${SUDO} apt-get --quiet update
}

install_w32codecs()
{
  install_medibuntu
  ${SUDO} apt-get install w32codecs
}

if test $# -eq 0 ; then
    echo "Usage: $0 <install targets>"
    exit 0
fi

for target in $* ; do
    install_${target}
done

