#!/usr/bin/env python
# encoding: utf-8

from __future__ import print_function

from distutils.version import StrictVersion
import os.path
import pdb
import re
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
            "path": "/Applications/TorBrowserBundle_en-US.app/",
            "unpacked_bundle": "TorBrowserBundle_en-US.app",
            "bundle_re": re.compile(
                "TorBrowserBundle-(\d+(\.\d+)*)-osx32_en-US.zip")

        },
    }

    def __init__(self, platform=None):
        platform = platform if platform else sys.platform
        try:
            self.params = self._params[platform]
        except KeyError:
            raise KeyError("Unknown platform '{}'".format(platform))

    def __getitem__(self, name):
        return self.params[name]

######################################################################


class TBBInstallation(object):
    """Representation of local installation of Tor Browser Bundle"""
    def __init__(self, install_path=None):
        self.config = SystemConfiguration()
        self.path = path(install_path) if install_path \
            else path(self.config["path"])

    def exists(self):
        """Return True if installation exists."""
        return self.path.exists()

    def move_aside(self):
        """Move installation aside to make way for new one"""
        new_path = self.path.normpath() + ".OLD"
        subprocess.check_call(["/usr/bin/sudo", "mv", self.path, new_path])
        self.path = new_path

    def version(self):
        """Return version of installed application

        Returns a distutils.version.StrictVersion instance
        or None if not installed or version unknown."""
        version_path = self.version_file_path
        if not version_path.exists():
            return None
        try:
            with version_path.open() as f:
                version_string = f.read()
        except IOError:
            return None
        try:
            version = StrictVersion(version_string)
        except ValueError:
            return None
        return version

    def set_version(self, version):
        """Set version of installation to given version

        version as a distutils.version.StrictVersion instance."""
        version_path = self.version_file_path
        version_path.write_lines([str(version)])

    @property
    def version_file_path(self):
        """Return path object representing version file."""
        return self.path / "VERSION"

######################################################################


class TBBInstaller(object):
    """Install a downloaded bundle."""

    def __init__(self, target_path=None):
        self.config = SystemConfiguration()
        self.path = path(target_path) if target_path \
            else path(self.config["path"])

    def install_bundle(self, bundle_path, target_path=None):
        """Create new installation from bundle.

        Returns TBBInstallation instance."""
        unpacked_bundle = self.unpack_bundle(bundle_path)
        install = TBBInstallation(target_path)
        if install.exists():
            install.move_aside()
            install = TBBInstallation(target_path)
        subprocess.check_call(["/usr/bin/sudo", "mv",
                               str(unpacked_bundle),
                               str(install.path)])
        return TBBInstallation(target_path)

    def unpack_bundle(self, bundle_path):
        """Unpack bundle based on its file extension."""
        tmp_dir = tempfile.mkdtemp()
        os.chdir(tmp_dir)
        if bundle_path.endswith(".zip"):
            self.unzip_bundle(bundle_path)
        elif bundle_path.endswith(".tar.gz"):
            sh.tar("xfz", bundle_path)
        else:
            raise NotImplementedError(
                "Do not know how to unpack {}".format(bundle_path))
        unpacked_bundle = path(self.config["unpacked_bundle"])
        if not unpacked_bundle.exists():
            raise RuntimeError("Could not find unpacked bundle \"{}\"".
                               format(unpacked_bundle))
        return unpacked_bundle

    def unzip_bundle(self, bundle_path):
        """Unpack zipped bundle"""
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

######################################################################


class TorWebSite(object):

    def __init__(self, base_url="https://www.torproject.org/"):
        self.base_url = base_url
        self.config = SystemConfiguration()

    def get_bundle_info(self):
        """Return (bundle URL, signature URL, version) for bundle.

        Returns version as a distutils.version.StrictVersion instance."""
        r = requests.get(self.base_url + "projects/torbrowser.html.en")
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
        return (url, signature_url, StrictVersion(m.group(1)))


######################################################################


class TBBInstallApp(cli.app.CommandLineApp):

    bundle_signing_gpg_key = "0x63FEE659"

    # Functions part of CommandLineApp API

    def main(self):
        self.debug("main() entered")
        self.check_params()
        self.check_gpg()
        web_site = TorWebSite()
        download_url, signature_url, latest_version = \
            web_site.get_bundle_info()
        self.debug("Latest version is {} at {}".format(latest_version,
                                                       download_url))
        installation = TBBInstallation()
        if installation.exists():
            installed_version = installation.version()
            if installed_version:
                self.debug("Installed version: {}".format(installed_version))
                if not(latest_version > installed_version):
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
        self.print("Installing version {}".format(latest_version))
        self.print("Downloading {}".format(download_url))
        bundle_path = path(
            self.download_file(download_url,
                               show_progress=not self.params.quiet))
        self.debug("Downloaded to {}".format(bundle_path))
        self.debug("Downloading {}".format(signature_url))
        signature_path = path(
            self.download_file(signature_url, show_progress=False))
        self.debug("Downloaded to {}".format(signature_path))
        self.check_gpg_signature(bundle_path, signature_path)
        installer = TBBInstaller()
        self.print("Installing to {}".format(installer.path))
        new_installation = installer.install_bundle(bundle_path)
        new_installation.set_version(latest_version)
        self.print("Success. New install at {}".format(new_installation.path))
        return 0

    def setup(self):
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
        """Check params"""
        if self.params.debug and self.params.quiet:
            raise RuntimeError(
                "Debug (-d) and quiet (-q) modes are incompatible.")

    def check_gpg(self):
        """Set self.gpg or raise exception if gpg cannot be found"""
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
        """Check signature for bundle"""
        output = self.gpg("--verify", signature_path, bundle_path)
        if output.exit_code != 0:
            raise RuntimeError("Signature check on bundle failed")

    # Utility functions

    def download_file(self, url, show_progress=True):
        """Download file at given URL.

        Show progress if show_progress is True.

        Creates temporary directory to hold file.
        Returns full path to downloaded file."""
        # Kudos: http://stackoverflow.com/a/16696317/197789
        head = requests.head(url)
        try:
            size = int(head.headers["content-length"])
        except KeyError:
            # Can't determine size, guess
            size = 25000000
        tmp_dir = tempfile.mkdtemp()
        local_filename = os.path.join(tmp_dir, url.split('/')[-1])
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

    def debug(self, msg):
        """Print a debug message"""
        if self.params.debug:
            print(msg)

    @staticmethod
    def print_error(msg):
        """Print an error message"""
        print(msg, file=sys.stderr)

    def print(self, msg):
        """Print a regular message"""
        if not self.params.quiet:
            print(msg)

if __name__ == "__main__":
    app = TBBInstallApp()
    try:
        app.run()
    except SystemExit as ex:
        sys.exit(ex.code)
    except:
        type, value, tb = sys.exc_info()
        traceback.print_exc()
        pdb.post_mortem(tb)
