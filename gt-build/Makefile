VERSION=4.0.3

# Break version down into three fields
MAJOR_VERSION=`echo $(VERSION) | cut -d . -f 1`
MINOR_VERSION=`echo $(VERSION) | cut -d . -f 2`
POINT_VERSION=`echo $(VERSION) | cut -d . -f 3`

# Where to download to
DOWNLOAD_DIR=/Users/vwelch/scratch/
# Where to build
BUILD_DIR=/tmp
# Base name for installer package
INSTALLER_BASE=gt$(VERSION)-all-source-installer
# Installer tar ball
INSTALLER=$(INSTALLER_BASE).tar.gz
# Unpacked installer directory
INSTALLER_DIR=$(BUILD_DIR)/$(INSTALLER_BASE)
# URL from where we get the installer
INSTALLER_URL=ftp://ftp.globus.org/pub/gt$(MAJOR_VERSION)/$(MAJOR_VERSION).$(MINOR_VERSION)/$(VERSION)/installers/src/$(INSTALLER)
# Globus location
GLOBUS_LOCATION=/usr/local/gt-$(VERSION)
# Command to set GL environment
SET_GL=export GLOBUS_LOCATION=$(GLOBUS_LOCATION)
# Build log
BUILD_LOG=$(GLOBUS_LOCATION)/build-log
# tee command to run to save a log file
TEE=tee -a $(BUILD_LOG)

# Various binaries and commands
DATE=date
MKDIR=mkdir
DIR_EXISTS = test -d
RM=rm -f
TAR=tar
WGET=wget
TOUCH=touch

# Flags for keeping track of our progress
INSTALLER_FLAG=$(DOWNLOAD_DIR)/gt-build-flag-installer-$(VERSION)
UNPACKED_FLAG=$(INSTALLER_DIR)/gt-build-flag-unpacked
CONFIGURE_FLAG=$(INSTALLER_DIR)/gt-build-flag-configured
BUILD_FLAG=$(INSTALLER_DIR)/gt-build-flag-built
INSTALL_FLAG=$(GLOBUS_LOCATION)/gt-build-flag-install

default: install

$(GLOBUS_LOCATION):
	$(MKDIR) $(GLOBUS_LOCATION)

installer: $(INSTALLER_FLAG)

$(INSTALLER_FLAG):
	$(RM) $(INSTALLER)
	(cd $(DOWNLOAD_DIR) && $(WGET) $(INSTALLER_URL) && $(TOUCH) $(INSTALLER_FLAG))

unpacked: installer $(UNPACKED_FLAG)

$(UNPACKED_FLAG):
	(cd $(BUILD_DIR) && $(TAR) xvfz $(DOWNLOAD_DIR)/$(INSTALLER) && $(TOUCH) $(UNPACKED_FLAG))

configure: unpacked $(CONFIGURE_FLAG)

$(CONFIGURE_FLAG):
	($(SET_GL) && cd $(INSTALLER_DIR) && ./configure --prefix=$(GLOBUS_LOCATION) && $(TOUCH) $(CONFIGURE_FLAG)) | $(TEE)

build: configure $(BUILD_FLAG)

$(BUILD_FLAG):
	($(SET_GL) && cd $(INSTALLER_DIR) && $(MAKE) && $(TOUCH) $(BUILD_FLAG)) | $(TEE)

install: $(INSTALL_FLAG)

$(INSTALL_FLAG): $(GLOBUS_LOCATION) build
	($(SET_GL) && cd $(INSTALLER_DIR) && $(MAKE) install && $(TOUCH) $(INSTALL_FLAG)) | $(TEE)

clean:
	$(RM) -rf $(INSTALL_DIR)
