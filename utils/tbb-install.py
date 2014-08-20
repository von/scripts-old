#!/usr/bin/env python
# encoding: utf-8

from __future__ import print_function

import atexit
import collections
from distutils.version import StrictVersion
import getpass
import os.path
import pdb
import re
import shutil
import subprocess
import sys
import tempfile
import urlparse
import traceback

try:
    from path import path
except ImportError as ex:
    print("Failed to import path: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install path.py", file=sys.stderr)
    sys.exit(1)

try:
    import cli.app
except ImportError as ex:
    print("Failed to import cli.app: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install pyCLI", file=sys.stderr)
    sys.exit(1)

try:
    import requests
except ImportError as ex:
    print("Failed to import requests: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install requests", file=sys.stderr)
    sys.exit(1)

try:
    from bs4 import BeautifulSoup
except ImportError as ex:
    print("Failed to import BeautifulSoup: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install beautifulsoup4", file=sys.stderr)
    sys.exit(1)

try:
    from progressbar import Bar, Percentage, ProgressBar
except ImportError as ex:
    print("Failed to import progressbar: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install progressbar", file=sys.stderr)
    sys.exit(1)

try:
    import sh  # noqa
except ImportError as ex:
    print("Failed to import sh: {}".format(str(ex)),
          file=sys.stderr)
    print("try: pip install sh", file=sys.stderr)
    sys.exit(1)

######################################################################


class SystemConfiguration(object):
    """Platform-specific configuration"""

    # Kudos to http://stackoverflow.com/a/8816338/197789 for the version
    # matching regex
    _params = {
        "darwin": {
            "path": "/Applications/TorBrowser.app/",
            "unpacked_bundle": "TorBrowser.app",
            "bundle_re": re.compile(
                "TorBrowser-(\d+(\.\d+)*)-osx32_en-US.dmg")
        },
    }

    def __init__(self, platform=None):
        """Initialize platform-specific configuration

        :param platform: Patform to use for configuration
            Default: sys.platform
        :raises KeyError: Unknown platform
        """
        platform = platform if platform else sys.platform
        try:
            self.params = self._params[platform]
        except KeyError:
            raise KeyError("Unknown platform '{}'".format(platform))

    def __getitem__(self, name):
        """Return configuration item

        :param name: Item name
        :raises KeyError: Unknown item
        """
        return self.params[name]

######################################################################


class TBBInstallation(object):
    """Representation of local installation of Tor Browser Bundle"""
    def __init__(self, install_path=None):
        self.config = SystemConfiguration()
        self.path = path(install_path) if install_path \
            else path(self.config["path"])

    def exists(self):
        """Check to see if installation exists.

        :returns: True if installation exists.
        """
        return self.path.exists()

    def version(self):
        """Return version of installed application

        :returns: StrictVersion instance or None on error.
        """
        version_path = self.version_file_path
        if not version_path.exists():
            return None
        version_re = re.compile("TORBROWSER_VERSION=(.*)")
        try:
            with version_path.open() as f:
                for line in f.readlines():
                    m = version_re.search(line)
                    if m:
                        version_string = m.group(1)
                        break
                else:
                    return None
        except IOError:
            return None
        try:
            version = StrictVersion(version_string)
        except ValueError:
            return None
        return version

    @property
    def version_file_path(self):
        """Return path to file containing version information

        :returns: Path as path instance
        """
        return self.path / "Docs/sources/versions"

######################################################################


class TBBInstaller(object):
    """Install a downloaded bundle."""

    def __init__(self):
        """Initialize a TBBInstaller"""
        self.config = SystemConfiguration()

    def install_bundle(self, bundle_path, target_path=None):
        """Create new installation from bundle.

        :param bundle_path: Path to bundle to install from
        :param target_path: Path to install to (will install
            to system default)
        """
        unpacked_bundle = self.unpack_bundle(bundle_path)
        target_path = path(target_path) if target_path \
            else path(self.config["path"])
        install = TBBInstallation(target_path)
        if install.exists():
            new_path = install.path.normpath() + ".OLD"
            if new_path.exists():
                self.as_root(["rm", "-rf", new_path])
            self.as_root(["mv", install.path.normpath(), new_path])
        self.as_root(["cp",
                      "-R",  # Recursive
                      str(unpacked_bundle),
                      str(install.path)])
        # Being owned by root creates strange problems opening the
        # application and "Firefox is already running" errors.
        self.as_root(["chown",
                      "-R",
                      getpass.getuser(),
                      str(install.path)])
        return TBBInstallation(target_path)

    def unpack_bundle(self, bundle_path):
        """Unpack bundle based on its file extension.

        :param bundle_path: path to bundle to unpack
        :returns: path to unpacked bundle
        :raises NotImplementedError: Unknown file extension on bundle
        :raises RunTimeError: Unpacking errors
        """
        tmp_dir = tempfile.mkdtemp()
        atexit.register(shutil.rmtree, tmp_dir, ignore_errors=True)
        os.chdir(tmp_dir)
        if bundle_path.endswith(".zip"):
            unpacked_bundle = self.unzip_bundle(bundle_path)
        elif bundle_path.endswith(".tar.gz"):
            unpacked_bundle = sh.tar("xfz", bundle_path)
        if bundle_path.endswith(".dmg"):
            unpacked_bundle = self.unpack_dmg(bundle_path)
        else:
            raise NotImplementedError(
                "Do not know how to unpack {}".format(bundle_path.basename()))
        return unpacked_bundle

    def unzip_bundle(self, bundle_path):
        """Unpack zipped bundle

        :param bundle_path: path to bundle to unzip
        :returns unpacked_bundle: path to unpacked bundle
        """
        import zipfile
        zf = zipfile.ZipFile(bundle_path)
        uncompressed_size = sum((file.file_size for file in zf.infolist()))
        pbar = ProgressBar(widgets=[Percentage(), Bar()],
                           maxval=uncompressed_size)
        pbar.start()
        extracted_size = 0
        for file in zf.infolist():
            extracted_size += file.file_size
            zf.extract(file)
            pbar.update(extracted_size)
        pbar.finish()
        unpacked_bundle = path(self.config["unpacked_bundle"])
        if not unpacked_bundle.exists():
            raise RuntimeError("Could not find unpacked bundle \"{}\"".
                               format(unpacked_bundle))
        return unpacked_bundle

    def untar_bundle(self, bundle_path):
        """Unpack tarred bundle

        :param bundle_path: path to bundle to unzip
        :returns unpacked_bundle: path to unpacked bundle
        """
        unpacked_bundle = sh.tar("xfz", bundle_path)
        unpacked_bundle = path(self.config["unpacked_bundle"])
        if not unpacked_bundle.exists():
            raise RuntimeError("Could not find unpacked bundle \"{}\"".
                               format(unpacked_bundle))
        return unpacked_bundle

    def unpack_dmg(self, bundle_path):
        """Unpack DMG

        :param bundle_path: path to bundle to unpack
        :returns unpacked_bundle: path to unpacked bundle
        """
        cwd = path.getcwd()
        mount_info = sh.hdiutil("attach",
                                "-noverify",  # Avoid output
                                "-mountroot", cwd,
                                bundle_path)
        dev, hint, mount_point = [s.strip() for s in mount_info.split("\t")]
        atexit.register(sh.hdiutil, "detach", mount_point, "-force")
        unpacked_bundle = path(mount_point) / \
            path(self.config["unpacked_bundle"])
        if not unpacked_bundle.exists():
            raise RuntimeError("Could not find unpacked bundle \"{}\"".
                               format(unpacked_bundle))
        return unpacked_bundle

    @staticmethod
    def as_root(cmdargs):
        """Run a command as root

        :param cmdargs: List of arguments to execute
        """
        # Can't do this with the sh module as it hangs if sudo needs
        # a password.
        subprocess.check_call(["/usr/bin/sudo"] + cmdargs)

    @property
    def path(self):
        """Return path installer will install to by default

        :returns: Path as path instance
        """
        return path(self.config["path"])

######################################################################


class TorWebSite(object):
    """Representation of Tor website"""

    def __init__(self, base_url="https://www.torproject.org/"):
        """Create instance of Tor web site

        :param base_url: URL of web site
            (Default: https://www.torproject.org/)
        """
        self.base_url = base_url
        self.config = SystemConfiguration()

    def get_bundle_info(self):
        """Return information on bundle from Tor website

        :returns: BundleInfo instance
        :raises IOError: Error accessing website
        :raises RunTimeError: Could not find link for bundle
        """
        try:
            r = requests.get(self.base_url + "projects/torbrowser.html.en")
        except (requests.exceptions.HTTPError,
                requests.exceptions.ConnectionError) as ex:
            raise IOError("Could not access Tor website: " + str(ex))
        r.raise_for_status()
        soup = BeautifulSoup(r.text)
        bundle_re = self.config["bundle_re"]
        for link in soup.find_all("a"):
            url = link.get("href")
            m = bundle_re.search(url)
            if m:
                break
        else:
            raise RuntimeError(
                "Could not find bundle link on {}".format(r.url))
        # Create full, absolute URL
        url = urlparse.urljoin(r.url, url)
        signature_url = url + ".asc"
        info = BundleInfo(url, StrictVersion(m.group(1)), signature_url)
        return info


######################################################################

BundleInfo = collections.namedtuple("BundlInfo", ["url",
                                                  "version",
                                                  "signature_url"
                                                  ])

######################################################################


class TBBInstallApp(cli.app.CommandLineApp):
    """TBB installation and maintenance application"""

    # Displayed by help
    name = "tbb-install"

    bundle_signing_gpg_key = "0x63FEE659"

    # Functions part of CommandLineApp API

    def main(self):
        """Install or update Tor Browser Bundle to most recent version.

        Returns zero on success, non-zero on error.
        """
        self.debug("main() entered")
        self.check_params()
        self.check_gpg()
        web_site = TorWebSite()
        try:
            info = web_site.get_bundle_info()
        except (IOError,
                RuntimeError) as ex:
            self.print_error(ex)
            return 1
        self.debug("Latest version is {} at {}".format(info.version,
                                                       info.url))
        installation = TBBInstallation()
        if installation.exists():
            installed_version = installation.version()
            if installed_version:
                self.debug("Installed version: {}".format(installed_version))
                if not(info.version > installed_version):
                    self.print(
                        "Installed version ({}) up to date"
                        .format(installed_version))
                    if not self.params.force:
                        return 0
                    self.print(
                        "Force install requested. "
                        "Re-installing anyways.")
            else:
                self.debug("Cannot determine version of installation.")
        else:
            self.debug("No installation found.")
        self.print("Installing version {}".format(info.version))
        self.print("Downloading {}".format(info.url))
        bundle_path = path(
            self.download_file(info.url,
                               show_progress=not self.params.quiet))
        self.debug("Downloaded to {}".format(bundle_path))
        self.debug("Downloading {}".format(info.signature_url))
        signature_path = path(
            self.download_file(info.signature_url,
                               show_progress=False))
        self.debug("Downloaded to {}".format(signature_path))
        try:
            self.check_gpg_signature(bundle_path, signature_path)
        except RuntimeError as ex:
            self.print_error(ex)
            return 1
        installer = TBBInstaller()
        self.print("Installing to {}".format(installer.path))
        try:
            new_installation = installer.install_bundle(bundle_path)
        except (NotImplementedError,
                RuntimeError,
                subprocess.CalledProcessError) as ex:
            self.print_error(ex)
            return 1
        self.print("Success. New install at {}".format(new_installation.path))
        return 0

    def setup(self):
        """Set up application prior to calling main()"""
        # Calling superclass creates argparser
        # Kudos: http://stackoverflow.com/a/12387762/197789
        super(cli.app.CommandLineApp, self).setup()
        self.add_param("-d", "--debug", help="turn on debugging",
                       default=False, action="store_true")
        self.add_param("-f", "--force", help="force (re-)installation",
                       default=False, action="store_true")
        self.add_param("-q", "--quiet", help="quiet mode",
                       default=False, action="store_true")

    # Our functions
    def check_params(self):
        """Check commandline arguments

        :raises RuntimeError: Fault with arguments
        """
        if self.params.debug and self.params.quiet:
            raise RuntimeError(
                "Debug (-d) and quiet (-q) modes are incompatible.")

    def check_gpg(self):
        """Set self.gpg or raise exception if gpg cannot be found

        :raises RuntimeError: Cannot find GPG executable or key
        """
        self.debug("Finding gpg binary")
        try:
            from sh import gpg
        except ImportError:
            try:
                from sh import gpg2 as gpg
            except ImportError:
                raise RuntimeError("Cannot find gpg binary")
        self.gpg = gpg

        self.debug(
            "Checking for gpg key {}".format(
                self.bundle_signing_gpg_key))
        output = self.gpg("--list-keys", self.bundle_signing_gpg_key)
        if output.exit_code != 0:
            raise RuntimeError(
                "Needed GPG key not installed: {}".format(
                    self.bundle_signing_gpg_key))

    def check_gpg_signature(self, bundle_path, signature_path):
        """Check signature for bundle

        :param bundle_path: path to bundle file
        :param signature_path: path to signature file
        :raises RuntimeError: Signature verification failed
        """
        output = self.gpg("--verify", signature_path, bundle_path)
        if output.exit_code != 0:
            raise RuntimeError("Signature check on bundle failed")

    # Utility functions

    def download_file(self, url, show_progress=True, cache=True):
        """Download file at given URL.

        Creates temporary directory to hold file.

        :param url: Url to file to download
        :param show_progress: Show progress if show_progress is True.
            (Default value = True)
        :param cache: Allow for caching of file.
            (Default value = False)
        :returns: Path to downloaded file.
        """
        download_dir = self._cache_dir()
        filename = url.split('/')[-1]
        local_filename = os.path.join(download_dir, filename)
        if cache and os.path.exists(local_filename):
            self.debug("Using cached: {}".format(local_filename))
            return local_filename
        # Kudos: http://stackoverflow.com/a/16696317/197789
        head = requests.head(url)
        try:
            size = int(head.headers["content-length"])
        except KeyError:
            # Can't determine size, guess
            size = 25000000
        r = requests.get(url, stream=True)
        chunk_size = 1024
        num_chunks = size / chunk_size
        chunk_count = 0
        if show_progress:
            pbar = ProgressBar(widgets=[Percentage(), Bar()],
                               maxval=num_chunks + 1)
            pbar.start()
        with open(local_filename, 'wb') as f:
            for chunk in r.iter_content(chunk_size=chunk_size):
                if chunk:  # filter out keep-alive new chunks
                    f.write(chunk)
                    f.flush()
                    chunk_count += 1
                    if show_progress:
                        pbar.update(chunk_count)
        if show_progress:
            pbar.finish()
        return local_filename

    def _cache_dir(self):
        cache_dir = \
            os.path.join(tempfile.gettempdir(),
                         "tbb-install-cache-{}".format(os.getlogin()))
        if not os.path.exists(cache_dir):
            os.makedirs(cache_dir, 0700)
        return cache_dir

    def debug(self, msg):
        """Print a debug message

        :param msg: string to print
        """
        if self.params.debug:
            print(msg)

    @staticmethod
    def print_error(msg):
        """Print an error message

        :param msg: string to print
        """
        print(msg, file=sys.stderr)

    def print(self, msg):
        """Print a regular message

        :param msg: string to print
        """
        if not self.params.quiet:
            print(msg)

if __name__ == "__main__":
    app = TBBInstallApp()
    try:
        app.run()
    except SystemExit as ex:
        sys.exit(ex.code)
    except KeyboardInterrupt as ex:
        sys.exit(1)
    except:
        type, value, tb = sys.exc_info()
        traceback.print_exc()
        pdb.post_mortem(tb)
